import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';
import 'transaction_detail_dialog.dart';

/// Screen displaying all store sales transactions with filters and analytics summary.
class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Semua Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_off_outlined),
            tooltip: 'Reset Filter',
            onPressed: () => txProvider.resetFilters(),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'transactions'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'transactions'),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Filter & Metrics Section
              _buildTopFilters(context),

              // Transactions List
              Expanded(
                child: Consumer<TransactionProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      );
                    }

                    final transactions = provider.filteredTransactions;

                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 44,
                                color: AppTheme.outline,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada transaksi ditemukan',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      );
                    }

                    final width = MediaQuery.of(context).size.width;
                    if (width >= 700) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380,
                              mainAxisExtent: 110,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return _TransactionCard(
                            transaction: tx,
                            onTap: () =>
                                TransactionDetailDialog.show(context, tx),
                          );
                        },
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _TransactionCard(
                          transaction: tx,
                          onTap: () =>
                              TransactionDetailDialog.show(context, tx),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopFilters(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          // Search Invoice
          TextField(
            onChanged: (val) => provider.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Cari nomor nota atau nama kasir...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),

          // Date Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(context, 'all', 'Semua Waktu', provider),
                _buildChip(context, 'today', 'Hari Ini', provider),
                _buildChip(context, 'week', '7 Hari Terakhir', provider),
                _buildChip(context, 'month', 'Bulan Ini', provider),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Stats Overview Row
          Row(
            children: [
              Expanded(
                child: _buildMetricMiniCard(
                  'Total Penjualan',
                  AnimatedCurrencyText(
                    value: provider.totalRevenue,
                    style: AppTheme.numericSmallStyle.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.secondary,
                      fontSize: 14,
                    ),
                  ),
                  AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard(
                  'Transaksi Sukses',
                  AnimatedCountText(
                    count: provider.completedTransactions.length,
                    suffix: ' Nota',
                    style: AppTheme.numericSmallStyle.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      fontSize: 14,
                    ),
                  ),
                  AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String range,
    String label,
    TransactionProvider provider,
  ) {
    final isSelected = provider.quickDateFilter == range;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.surfaceContainerLow,
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => provider.setQuickDateFilter(range),
      ),
    );
  }

  Widget _buildMetricMiniCard(String label, Widget valueWidget, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valueWidget,
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionCard({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(transaction.createdAt);
    final financeProv = context.watch<FinanceProvider>();
    final debt = financeProv.findDebtByInvoice(transaction.invoiceNumber);

    // Sinkronkan status Lunas jika di menu Pengeluaran & Keuangan piutang sudah lunas
    final isCancelled = transaction.isCancelled;
    final isLunas = !isCancelled && (transaction.isCompleted || (debt != null && debt.isPaid));
    final isPiutang = !isCancelled && !isLunas &&
        (transaction.isUnpaid || debt != null || transaction.paymentMethod.toLowerCase() == 'piutang');
    final isCicilan = isPiutang && (debt != null && debt.paidAmount > 0);

    final sisaPiutang = debt != null
        ? debt.remainingAmount
        : (transaction.total - transaction.paidAmount).clamp(0.0, double.infinity);
    final terbayarPiutang = debt != null
        ? debt.paidAmount
        : transaction.paidAmount;

    Color badgeColor = isLunas
        ? AppTheme.primary
        : (isPiutang ? Colors.amber[800]! : AppTheme.error);

    String statusLabel = 'Lunas';
    if (isCancelled) {
      statusLabel = 'Batal';
    } else if (isCicilan) {
      statusLabel = 'Dicicil';
    } else if (isPiutang) {
      statusLabel = 'Belum Lunas';
    }

    return ScaleTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isLunas
                ? AppTheme.outlineVariant.withValues(alpha: 0.7)
                : (isPiutang
                      ? Colors.amber.withValues(alpha: 0.5)
                      : AppTheme.error.withValues(alpha: 0.35)),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLunas
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : (isPiutang
                          ? Colors.amber.withValues(alpha: 0.15)
                          : AppTheme.errorContainer),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                isLunas
                    ? Icons.receipt_long_rounded
                    : (isPiutang
                          ? (isCicilan ? Icons.payments_rounded : Icons.pending_actions_rounded)
                          : Icons.cancel_outlined),
                color: badgeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                transaction.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isLunas
                                    ? AppTheme.secondaryContainer
                                    : (isPiutang
                                          ? Colors.amber.withValues(alpha: 0.2)
                                          : AppTheme.errorContainer),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm,
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isLunas
                                      ? AppTheme.secondary
                                      : (isPiutang
                                            ? Colors.amber[900]
                                            : AppTheme.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(transaction.total),
                          style: AppTheme.numericSmallStyle.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isLunas
                                ? AppTheme.secondary
                                : (isPiutang
                                      ? Colors.amber[900]
                                      : AppTheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isPiutang
                              ? '${transaction.cashierName} • Terbayar: ${CurrencyFormatter.format(terbayarPiutang)} • Sisa: ${CurrencyFormatter.format(sisaPiutang)}'
                              : '${transaction.cashierName} • ${transaction.paymentMethod}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isPiutang ? Colors.amber[900] : AppTheme.outline,
                            fontWeight: isPiutang ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
