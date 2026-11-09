import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';
import 'user_form_dialog.dart';

/// Screen for managing Employees, Granular Permissions, Attendance Logs, Work Schedules, and Activity Audit Logs (PRD Section 5.10).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Karyawan, Absensi & Audit'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Karyawan & Akses'),
            Tab(text: 'Absensi & Jadwal'),
            Tab(text: 'Log Aktivitas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'Tambah Absensi Manual',
            onPressed: () => _showAddAttendanceDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
            tooltip: 'Tambah Jadwal Kerja',
            onPressed: () => _showAddScheduleDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Tambah Karyawan',
            onPressed: () => UserFormDialog.show(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'users'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'users'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => UserFormDialog.show(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Karyawan'),
        backgroundColor: AppTheme.primary,
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmployeesTab(context, userProvider),
              _buildAttendanceTab(context, attendanceProvider),
              _buildActivityLogsTab(context, attendanceProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesTab(BuildContext context, UserProvider userProvider) {
    final users = userProvider.filteredUsers;

    return Column(
      children: [
        // Search & Stats Bar
        Container(
          color: AppTheme.surfaceContainerLowest,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => userProvider.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Cari nama, jabatan, atau email karyawan...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: userProvider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => userProvider.setSearchQuery(''),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Total Karyawan (${userProvider.allUsers.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '${userProvider.cashiers.length} Staf / Kasir',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: userProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : users.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada karyawan ditemukan',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _UserCard(user: users[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab(
    BuildContext context,
    AttendanceProvider attendanceProv,
  ) {
    final logs = attendanceProv.attendanceLogs;
    final schedules = attendanceProv.workSchedules;

    return Column(
      children: [
        // Work schedules strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: AppTheme.surfaceContainerLow,
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: schedules.isEmpty
                    ? const Text(
                        'Belum ada jadwal shift tetap. Klik ikon jam di atas untuk menambah.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.outline,
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: schedules
                              .map(
                                (s) => InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull,
                                  ),
                                  onTap: () =>
                                      _showEditScheduleDialog(context, s),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${s.name}: ${s.startTime}-${s.endTime}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.edit_outlined,
                                          size: 13,
                                          color: AppTheme.outline,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada riwayat absensi login/logout.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildAttendanceCard(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceLogModel log) {
    final loginStr = DateFormat('dd MMM yyyy, HH:mm').format(log.loginAt);
    final logoutStr = log.logoutAt != null
        ? DateFormat('HH:mm').format(log.logoutAt!)
        : 'Masih Aktif';
    final isLate = log.status == 'terlambat';

    return ScaleTap(
      onTap: () => _showEditAttendanceDialog(context, log),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLate
                    ? AppTheme.errorContainer
                    : AppTheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: Icon(
                isLate ? Icons.warning_amber_rounded : Icons.how_to_reg_rounded,
                color: isLate ? AppTheme.error : AppTheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Masuk: $loginStr • Keluar: $logoutStr',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLate
                    ? AppTheme.errorContainer
                    : AppTheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                isLate ? 'TERLAMBAT' : 'TEPAT WAKTU',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isLate
                      ? AppTheme.error
                      : AppTheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogsTab(
    BuildContext context,
    AttendanceProvider attendanceProv,
  ) {
    final logs = attendanceProv.activityLogs;
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada log aktivitas sistem.',
          style: TextStyle(color: AppTheme.outline),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final act = logs[index];
        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(act.createdAt);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.history_edu_rounded,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${act.module.toUpperCase()} • ${act.action}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      act.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Oleh: ${act.userName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Shift Pagi');
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '16:00');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tambah Jadwal Shift Kerja',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Jadwal (e.g. Shift Pagi)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jam Masuk (HH:mm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jam Pulang (HH:mm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          await context
                              .read<AttendanceProvider>()
                              .saveWorkSchedule(
                                userId: nameCtrl.text
                                    .trim()
                                    .toLowerCase()
                                    .replaceAll(' ', '_'),
                                userName: nameCtrl.text.trim(),
                                dayOfWeek: 'Setiap Hari',
                                startTime: startCtrl.text.trim(),
                                endTime: endCtrl.text.trim(),
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditScheduleDialog(
    BuildContext context,
    WorkScheduleModel schedule,
  ) {
    final nameCtrl = TextEditingController(text: schedule.name);
    final startCtrl = TextEditingController(text: schedule.startTime);
    final endCtrl = TextEditingController(text: schedule.endTime);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Ubah Jadwal Shift',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.error,
                      ),
                      tooltip: 'Hapus Jadwal',
                      onPressed: () async {
                        await context
                            .read<AttendanceProvider>()
                            .deleteWorkSchedule(schedule.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Jadwal'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jam Masuk (HH:mm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Jam Pulang (HH:mm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          await context
                              .read<AttendanceProvider>()
                              .saveWorkSchedule(
                                id: schedule.id,
                                userId: schedule.userId,
                                userName: nameCtrl.text.trim(),
                                dayOfWeek: schedule.dayOfWeek,
                                startTime: startCtrl.text.trim(),
                                endTime: endCtrl.text.trim(),
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAttendanceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String role = 'kasir';
    String status = 'tepat';
    final inTimeCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );
    final outTimeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tambah Catatan Absensi Manual',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Karyawan *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status Kehadiran',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'tepat',
                        child: Text('Tepat Waktu'),
                      ),
                      DropdownMenuItem(
                        value: 'terlambat',
                        child: Text('Terlambat'),
                      ),
                      DropdownMenuItem(
                        value: 'pulang_awal',
                        child: Text('Pulang Lebih Awal'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: inTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Masuk (yyyy-MM-dd HH:mm)',
                      prefixIcon: Icon(Icons.login_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: outTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Keluar (Opsional, yyyy-MM-dd HH:mm)',
                      prefixIcon: Icon(Icons.logout_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final loginAt =
                                DateTime.tryParse(inTimeCtrl.text.trim()) ??
                                DateTime.now();
                            final logoutAt = outTimeCtrl.text.trim().isNotEmpty
                                ? DateTime.tryParse(outTimeCtrl.text.trim())
                                : null;

                            await context
                                .read<AttendanceProvider>()
                                .saveAttendanceLog(
                                  userId: nameCtrl.text
                                      .trim()
                                      .toLowerCase()
                                      .replaceAll(' ', '_'),
                                  userName: nameCtrl.text.trim(),
                                  userRole: role,
                                  loginAt: loginAt,
                                  logoutAt: logoutAt,
                                  status: status,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditAttendanceDialog(BuildContext context, AttendanceLogModel log) {
    String status = log.status;
    final inTimeCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(log.loginAt),
    );
    final outTimeCtrl = TextEditingController(
      text: log.logoutAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(log.logoutAt!)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Absensi: ${log.userName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                        ),
                        tooltip: 'Hapus Catatan Absensi',
                        onPressed: () async {
                          await context
                              .read<AttendanceProvider>()
                              .deleteAttendanceLog(log.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status Kehadiran',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'tepat',
                        child: Text('Tepat Waktu'),
                      ),
                      DropdownMenuItem(
                        value: 'terlambat',
                        child: Text('Terlambat'),
                      ),
                      DropdownMenuItem(
                        value: 'pulang_awal',
                        child: Text('Pulang Lebih Awal'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: inTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Masuk (yyyy-MM-dd HH:mm)',
                      prefixIcon: Icon(Icons.login_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: outTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Keluar (yyyy-MM-dd HH:mm)',
                      prefixIcon: Icon(Icons.logout_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final loginAt =
                                DateTime.tryParse(inTimeCtrl.text.trim()) ??
                                log.loginAt;
                            final logoutAt = outTimeCtrl.text.trim().isNotEmpty
                                ? DateTime.tryParse(outTimeCtrl.text.trim())
                                : null;

                            await context
                                .read<AttendanceProvider>()
                                .saveAttendanceLog(
                                  id: log.id,
                                  userId: log.userId,
                                  userName: log.userName,
                                  userRole: log.userRole,
                                  loginAt: loginAt,
                                  logoutAt: logoutAt,
                                  status: status,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Simpan Perubahan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.isAdmin;
    final dateStr = DateFormat('dd/MM/yyyy').format(user.createdAt);

    return ScaleTap(
      onTap: () => UserFormDialog.show(context, userToEdit: user),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: user.isActive
                ? AppTheme.outlineVariant.withValues(alpha: 0.4)
                : AppTheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: isAdmin
                  ? AppTheme.primaryContainer
                  : AppTheme.secondaryContainer,
              child: Text(
                (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAdmin ? Colors.white : AppTheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user.name} (${user.position})',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? AppTheme.primary
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'ADMIN' : 'KASIR',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.email}${user.phone.isNotEmpty ? " • ${user.phone}" : ""}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.outline),
                  ),
                  if (user.permissions.isNotEmpty && !isAdmin) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: user.permissions
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                              ),
                              child: Text(
                                AppConstants.permissionLabel(p),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? AppTheme.secondaryContainer
                              : AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          user.isActive ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: user.isActive
                                ? AppTheme.onSecondaryContainer
                                : AppTheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Terdaftar: $dateStr',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit Profil & Hak Akses',
              onPressed: () => UserFormDialog.show(context, userToEdit: user),
            ),

            // Toggle Active Switch (Only for Cashier, cannot disable admin)
            if (!isAdmin)
              IconButton(
                icon: Icon(
                  user.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: user.isActive ? AppTheme.secondary : AppTheme.outline,
                  size: 32,
                ),
                tooltip: user.isActive ? 'Nonaktifkan Akun' : 'Aktifkan Akun',
                onPressed: () {
                  context.read<UserProvider>().toggleUserStatus(user);
                },
              ),
          ],
        ),
      ),
    );
  }
}
