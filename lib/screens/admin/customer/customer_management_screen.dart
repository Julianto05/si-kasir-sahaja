import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/customer_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Module 5.8: Pelanggan, Member & Loyalitas.
class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custProv = context.watch<CustomerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Pelanggan, Member & Poin'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_rounded, size: 18),
              text: 'Pelanggan (${custProv.allCustomers.length})',
            ),
            Tab(
              icon: const Icon(Icons.stars_rounded, size: 18),
              text: 'Riwayat Poin (${custProv.pointLogs.length})',
            ),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: 'customers'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'customers'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CustomerFormDialog.show(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Pelanggan'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCustomersTab(context, custProv),
              _buildPointLogsTab(context, custProv),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomersTab(BuildContext context, CustomerProvider custProv) {
    final customers = custProv.filteredCustomers;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          color: AppTheme.surfaceContainerLowest,
          child: Column(
            children: [
              TextField(
                onChanged: custProv.setSearchQuery,
                decoration: const InputDecoration(
                  hintText: 'Cari nama, kode member, atau nomor WhatsApp...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Hanya Member Aktif'),
                    selected: custProv.onlyMembers,
                    onSelected: (_) => custProv.toggleOnlyMembers(),
                    selectedColor: AppTheme.secondaryContainer,
                  ),
                  const Spacer(),
                  Text(
                    '${custProv.memberCustomers.length} Member Terdaftar',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: customers.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data pelanggan atau member.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isLandscape ? 2 : 1,
                    mainAxisExtent: 116,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    return ScaleTap(
                      onTap: () => _showCustomerDetailSheet(context, c),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color: c.isMember
                                ? AppTheme.secondary.withValues(alpha: 0.4)
                                : AppTheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: c.isMember
                                  ? AppTheme.secondary.withValues(alpha: 0.15)
                                  : AppTheme.primary.withValues(alpha: 0.1),
                              child: Icon(
                                c.isMember
                                    ? Icons.workspace_premium_rounded
                                    : Icons.person_rounded,
                                color: c.isMember
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (c.isMember) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondary,
                                            borderRadius: BorderRadius.circular(
                                                AppTheme.radiusSm),
                                          ),
                                          child: const Text(
                                            'MEMBER',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${c.code} • WA: ${c.whatsapp.isNotEmpty ? c.whatsapp : "-"}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Belanja: ${CurrencyFormatter.format(c.totalSpent)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.stars_rounded,
                                          size: 14, color: Color(0xFFD97706)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${c.points} Poin',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPointLogsTab(BuildContext context, CustomerProvider custProv) {
    final logs = custProv.pointLogs;
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada riwayat perolehan atau penukaran poin.',
          style: TextStyle(color: AppTheme.outline),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isEarn = log.type == 'earn';
        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(log.createdAt);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isEarn ? Icons.add_circle_rounded : Icons.redeem_rounded,
                color: isEarn ? AppTheme.secondary : AppTheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.customerName.isNotEmpty
                          ? log.customerName
                          : 'Pelanggan #${log.customerId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${isEarn ? "Perolehan Poin Belanja" : "Penukaran Poin Diskon"} • $dateStr',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.outline),
                    ),
                  ],
                ),
              ),
              Text(
                '${isEarn ? "+" : "-"}${log.points} Poin',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isEarn ? AppTheme.secondary : AppTheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerDetailSheet(BuildContext context, CustomerModel customer) {
    final allTx = context.read<TransactionProvider>().allTransactions;
    final customerTx =
        allTx.where((tx) => tx.customerId == customer.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      CustomerFormDialog.show(context, customer: customer);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              Text(
                '${customer.code} • WhatsApp: ${customer.whatsapp.isNotEmpty ? customer.whatsapp : "-"}',
                style: const TextStyle(fontSize: 12, color: AppTheme.outline),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Belanja',
                              style: TextStyle(fontSize: 11)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(customer.totalSpent),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        children: [
                          const Text('Poin Loyalitas',
                              style: TextStyle(fontSize: 11)),
                          Text(
                            '${customer.points} Poin',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Riwayat Belanja (${customerTx.length} Transaksi)',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              if (customerTx.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada transaksi tercatat.',
                      style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                )
              else
                ...customerTx.take(5).map((tx) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt)),
                      trailing: Text(
                        CurrencyFormatter.format(tx.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for adding or editing a Customer / Member (reusable from Admin & POS).
class CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  static Future<CustomerModel?> show(BuildContext context,
      {CustomerModel? customer}) {
    return showDialog<CustomerModel>(
      context: context,
      builder: (_) => CustomerFormDialog(customer: customer),
    );
  }

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _addrCtrl;
  late bool _isMember;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _waCtrl = TextEditingController(text: widget.customer?.whatsapp ?? '');
    _addrCtrl = TextEditingController(text: widget.customer?.address ?? '');
    _isMember = widget.customer?.isMember ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _waCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.customer == null
                    ? 'Daftar Pelanggan / Member Baru'
                    : 'Edit Data Pelanggan',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Pelanggan *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _waCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp / HP',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addrCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Member Loyalitas',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Berhak mendapat diskon khusus member & poin belanja',
                  style: TextStyle(fontSize: 11),
                ),
                value: _isMember,
                activeThumbColor: AppTheme.secondary,
                onChanged: (v) => setState(() => _isMember = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              if (_nameCtrl.text.trim().isEmpty) return;
                              setState(() => _isSaving = true);
                              final prov = context.read<CustomerProvider>();
                              if (widget.customer == null) {
                                final created = await prov.addCustomer(
                                  name: _nameCtrl.text,
                                  whatsapp: _waCtrl.text,
                                  address: _addrCtrl.text,
                                  isMember: _isMember,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, created);
                                }
                              } else {
                                final updated = widget.customer!.copyWith(
                                  name: _nameCtrl.text,
                                  whatsapp: _waCtrl.text,
                                  address: _addrCtrl.text,
                                  isMember: _isMember,
                                );
                                await prov.updateCustomer(updated);
                                if (context.mounted) {
                                  Navigator.pop(context, updated);
                                }
                              }
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
    );
  }
}

