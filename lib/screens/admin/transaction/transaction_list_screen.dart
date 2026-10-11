import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
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
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Reset Filter',
            onPressed: () => txProvider.resetFilters(),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'transactions'),
      body: SafeArea(
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
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final transactions = provider.filteredTransactions;

                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppTheme.outline),
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
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        childAspectRatio: 3.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
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
                    padding: const EdgeInsets.all(12),
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    );
  }

  Widget _buildTopFilters(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Container(
      color: AppTheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search Invoice
          TextField(
            onChanged: (val) => provider.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Cari nomor nota atau nama kasir...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Date Quick Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(context, 'all', 'Semua Waktu', provider),
                _buildChip(context, 'today', 'Hari Ini', provider),
                _buildChip(context, 'week', '7 Hari', provider),
                _buildChip(context, 'month', 'Bulan Ini', provider),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Stats Overview Row
          Row(
            children: [
              Expanded(
                child: _buildMetricMiniCard(
                  'Total Penjualan',
                  CurrencyFormatter.format(provider.totalRevenue),
                  AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricMiniCard(
                  'Transaksi Sukses',
                  '${provider.completedTransactions.length}',
                  AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String range, String label,
      TransactionProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label),
        onPressed: () => provider.setQuickDateFilter(range),
      ),
    );
  }

  Widget _buildMetricMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.outline)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.numericSmallStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
    final dateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt);
    final isCompleted = transaction.isCompleted;

    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: isCompleted
                  ? AppTheme.outlineVariant.withValues(alpha: 0.4)
                  : AppTheme.error.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.receipt_long_rounded
                      : Icons.cancel_outlined,
                  color: isCompleted ? AppTheme.primary : AppTheme.error,
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
                        Text(
                          transaction.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(transaction.total),
                          style: AppTheme.numericSmallStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? AppTheme.secondary
                                : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${transaction.cashierName} • ${transaction.paymentMethod}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.outline),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
