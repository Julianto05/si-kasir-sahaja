import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/finance_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Module 5.9: Pengeluaran, Kas & Keuangan (Operational Expenses, Cashflow, Debts & Capital).
class FinanceManagementScreen extends StatefulWidget {
  const FinanceManagementScreen({super.key});

  @override
  State<FinanceManagementScreen> createState() =>
      _FinanceManagementScreenState();
}

class _FinanceManagementScreenState extends State<FinanceManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    final financeProv = context.watch<FinanceProvider>();
    final txProv = context.watch<TransactionProvider>();

    final grossProfit = txProv.totalProfit;
    final totalExpenses = financeProv.totalExpenses;
    final netProfit = grossProfit - totalExpenses;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Pengeluaran, Kas & Keuangan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.money_off_csred_rounded, size: 18),
              text: 'Pengeluaran (${financeProv.allExpenses.length})',
            ),
            Tab(
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              text: 'Utang & Piutang (${financeProv.allDebts.length})',
            ),
            Tab(
              icon: const Icon(Icons.savings_rounded, size: 18),
              text: 'Modal Usaha',
            ),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: 'finance'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'finance'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddExpenseBottomSheet(context);
          } else if (_tabController.index == 2) {
            _showAddCapitalBottomSheet(context);
          } else {
            _showAddManualDebtDialog(context);
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) return const Text('Catat Pengeluaran');
            if (_tabController.index == 1) return const Text('Catat Utang/Piutang');
            return const Text('Setor Modal');
          },
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Financial Cashflow Summary
              Container(
                padding: const EdgeInsets.all(14),
                color: AppTheme.surfaceContainerLowest,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCashSummaryBox(
                        'Laba Kotor POS',
                        CurrencyFormatter.format(grossProfit),
                        AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCashSummaryBox(
                        'Pengeluaran Toko',
                        CurrencyFormatter.format(totalExpenses),
                        AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCashSummaryBox(
                        'Laba Bersih',
                        CurrencyFormatter.format(netProfit),
                        netProfit >= 0 ? AppTheme.secondary : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpensesTab(context, financeProv),
                    _buildDebtsTab(context, financeProv),
                    _buildCapitalTab(context, financeProv),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(BuildContext context, FinanceProvider financeProv) {
    final expenses = financeProv.allExpenses;
    if (expenses.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada catatan pengeluaran operasional.',
          style: TextStyle(color: AppTheme.outline),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: expenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final exp = expenses[index];
        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exp.date);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: const Icon(Icons.trending_down_rounded,
                    color: AppTheme.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.expenseCategoryLabel(exp.category),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    if (exp.note.isNotEmpty)
                      Text(
                        exp.note,
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • Oleh: ${exp.createdByName}',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppTheme.outline),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${CurrencyFormatter.format(exp.amount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.error,
                      fontSize: 13.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => financeProv.deleteExpense(exp.id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtsTab(BuildContext context, FinanceProvider financeProv) {
    final debts = financeProv.allDebts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _buildCashSummaryBox(
                  'Sisa Utang Supplier',
                  CurrencyFormatter.format(financeProv.totalUnpaidSupplierDebt),
                  AppTheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCashSummaryBox(
                  'Piutang Pelanggan',
                  CurrencyFormatter.format(
                      financeProv.totalUnpaidCustomerReceivable),
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: debts.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada utang supplier atau piutang pelanggan.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                  itemCount: debts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = debts[index];
                    final isUtang = d.type == 'utang';
                    return ScaleTap(
                      onTap: d.isPaid
                          ? null
                          : () => _showPayDebtDialog(context, d),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color: d.isPaid
                                ? AppTheme.outlineVariant.withValues(alpha: 0.5)
                                : (isUtang
                                    ? AppTheme.error.withValues(alpha: 0.35)
                                    : const Color(0xFFD97706)
                                        .withValues(alpha: 0.35)),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isUtang
                                        ? AppTheme.errorContainer
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm),
                                  ),
                                  child: Text(
                                    isUtang
                                        ? 'UTANG SUPPLIER'
                                        : 'PIUTANG PELANGGAN',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isUtang
                                          ? AppTheme.error
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    d.isPaid
                                        ? 'LUNAS'
                                        : 'Sisa: ${CurrencyFormatter.format(d.remainingAmount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: d.isPaid
                                          ? AppTheme.secondary
                                          : AppTheme.error,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${d.partyName} (${d.referenceNo})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total: ${CurrencyFormatter.format(d.amount)} • Terbayar: ${CurrencyFormatter.format(d.paidAmount)}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppTheme.outline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!d.isPaid) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showPayDebtDialog(context, d),
                                  icon: const Icon(Icons.payments_outlined,
                                      size: 16),
                                  label: const Text('Bayar / Cicil',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
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

  Widget _buildCapitalTab(BuildContext context, FinanceProvider financeProv) {
    final entries = financeProv.allCapitalEntries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCashSummaryBox(
            'Total Akumulasi Setoran Modal Usaha',
            CurrencyFormatter.format(financeProv.totalCapital),
            AppTheme.secondary,
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada catatan setoran modal usaha.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cap = entries[index];
                    return ListTile(
                      tileColor: AppTheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      leading: const Icon(Icons.savings_rounded,
                          color: AppTheme.secondary),
                      title: Text(
                        CurrencyFormatter.format(cap.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${cap.note} • ${DateFormat('dd MMM yyyy').format(cap.date)}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Scrollable Bottom Sheet for adding an Operational Expense (PRD Section 5.9 & 6).
  void _showAddExpenseBottomSheet(BuildContext context) {
    String selectedCat = AppConstants.expenseCategories.first;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Catat Pengeluaran Operasional Toko',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Pengeluaran',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: AppConstants.expenseCategories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(AppConstants.expenseCategoryLabel(c)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedCat = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Pengeluaran (Rp) *',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (e.g. Token Listrik, Plastik Kresek)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final amt = CurrencyFormatter.parse(amountCtrl.text);
                    if (amt <= 0) return;
                    final user = context.read<AuthProvider>().currentUser;
                    await context.read<FinanceProvider>().addExpense(
                          category: selectedCat,
                          amount: amt,
                          note: noteCtrl.text,
                          date: DateTime.now(),
                          userId: user?.uid ?? 'admin',
                          userName: user?.name ?? 'Admin',
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error),
                  child: const Text('Simpan Pengeluaran'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCapitalBottomSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Setoran Modal Kas Toko');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Catat Setoran Modal Usaha',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nominal Setoran Modal (Rp) *',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final amt = CurrencyFormatter.parse(amountCtrl.text);
                  if (amt <= 0) return;
                  final user = context.read<AuthProvider>().currentUser;
                  await context.read<FinanceProvider>().addCapitalEntry(
                        amount: amt,
                        note: noteCtrl.text,
                        date: DateTime.now(),
                        userId: user?.uid ?? 'admin',
                        userName: user?.name ?? 'Admin',
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary),
                child: const Text('Simpan Modal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayDebtDialog(BuildContext context, DebtModel debt) {
    final payCtrl =
        TextEditingController(text: CurrencyFormatter.formatCompact(debt.remainingAmount));
    final noteCtrl = TextEditingController(text: 'Cicilan / Pelunasan');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bayar ${debt.type == "utang" ? "Utang Supplier" : "Piutang Pelanggan"}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${debt.partyName} • Sisa: ${CurrencyFormatter.format(debt.remainingAmount)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: payCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Pembayaran (Rp) *',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Pembayaran',
                    prefixIcon: Icon(Icons.notes_rounded),
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
                          final amt = CurrencyFormatter.parse(payCtrl.text);
                          if (amt <= 0) return;
                          final user =
                              context.read<AuthProvider>().currentUser;
                          await context.read<FinanceProvider>().payDebt(
                                debt: debt,
                                payAmount: amt,
                                method: 'Cash',
                                note: noteCtrl.text,
                                userId: user?.uid ?? 'admin',
                                userName: user?.name ?? 'Admin',
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondary),
                        child: const Text('Simpan Bayar'),
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

  void _showAddManualDebtDialog(BuildContext context) {
    String debtType = 'piutang';
    final nameCtrl = TextEditingController();
    final refCtrl = TextEditingController(text: 'MANUAL');
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Catat Utang / Piutang Baru',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: debtType,
                    decoration: const InputDecoration(labelText: 'Jenis'),
                    items: const [
                      DropdownMenuItem(
                          value: 'piutang',
                          child: Text('Piutang Pelanggan (Kasbon)')),
                      DropdownMenuItem(
                          value: 'utang', child: Text('Utang ke Supplier')),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => debtType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pelanggan / Supplier *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp) *',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Referensi / Keterangan',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final amt = CurrencyFormatter.parse(amtCtrl.text);
                      if (nameCtrl.text.trim().isEmpty || amt <= 0) return;
                      await context.read<FinanceProvider>().addManualDebt(
                            type: debtType,
                            partyName: nameCtrl.text.trim(),
                            referenceNo: refCtrl.text.trim(),
                            amount: amt,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Simpan Utang/Piutang'),
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
