import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/user_provider.dart';

/// Modal dialog for creating new cashier accounts or editing employee profiles & permissions (PRD Section 3 & 5.10).
class UserFormDialog extends StatefulWidget {
  final UserModel? userToEdit;

  const UserFormDialog({super.key, this.userToEdit});

  static Future<void> show(BuildContext context, {UserModel? userToEdit}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserFormDialog(userToEdit: userToEdit),
    );
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late final TextEditingController _positionController;
  String? _selectedScheduleId;
  late Set<String> _selectedPermissions;

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  bool get _isEditMode => widget.userToEdit != null;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _nameController = TextEditingController(text: u?.name ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _positionController = TextEditingController(text: u?.position ?? 'Kasir');
    _selectedScheduleId = u?.workScheduleId;
    _selectedPermissions = Set<String>.from(u?.permissions ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final userProvider = context.read<UserProvider>();
    bool success;

    if (_isEditMode) {
      success = await userProvider.updateUserProfileAndPermissions(
        uid: widget.userToEdit!.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        position: _positionController.text.trim(),
        permissions: _selectedPermissions.toList(),
        workScheduleId: _selectedScheduleId,
      );
    } else {
      success = await userProvider.createCashier(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        position: _positionController.text.trim(),
        permissions: _selectedPermissions.toList(),
        workScheduleId: _selectedScheduleId,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Profil & Hak Akses "${_nameController.text}" diperbarui!'
                : 'Akun karyawan "${_nameController.text}" berhasil dibuat!',
          ),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } else if (userProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<AttendanceProvider>().workSchedules;

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault,
                        ),
                      ),
                      child: Icon(
                        _isEditMode
                            ? Icons.manage_accounts_rounded
                            : Icons.person_add_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEditMode
                            ? 'Edit Profil & Hak Akses Karyawan'
                            : 'Tambah Karyawan / Kasir',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditMode,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Karyawan *',
                    hintText: 'e.g. Budi Santoso',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama karyawan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Phone & Position Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'No. HP / WhatsApp',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _positionController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Jabatan',
                          hintText: 'Kasir / Gudang',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Email & Password (Only when creating new account)
                if (!_isEditMode) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email Login *',
                      hintText: 'kasir@sikasirsahaja.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email wajib diisi';
                      }
                      if (!val.contains('@')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password Akun *',
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password wajib diisi';
                      }
                      if (val.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Work Schedule Selector
                if (schedules.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue:
                        schedules.any((s) => s.id == _selectedScheduleId)
                        ? _selectedScheduleId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Jadwal Shift Kerja',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Jadwal Fleksibel (Tanpa Shift Tetap)'),
                      ),
                      ...schedules.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.startTime} - ${s.endTime})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedScheduleId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Granular Permissions Section (PRD Section 3.2)
                if (!(widget.userToEdit?.isAdmin ?? false)) ...[
                  const Text(
                    'Hak Akses Modul Tambahan (Granular Permissions):',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: AppConstants.allPermissions.map((perm) {
                        final checked = _selectedPermissions.contains(perm);
                        return CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            AppConstants.permissionLabel(perm),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: checked,
                          activeColor: AppTheme.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPermissions.add(perm);
                              } else {
                                _selectedPermissions.remove(perm);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isEditMode ? 'Simpan' : 'Buat Akun'),
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
}
