import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Screen displaying financial reports, net profit/loss (deducting operational expenses),
/// cashier sales breakdown, top products, and dead stock analytics (PRD Section 5.5).
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final prodProvider = context.watch<ProductProvider>();
    final completedTx = txProvider.completedTransactions;

    // Operational expenses in the selected date filter
    final periodExpenses = financeProvider.expensesInRange(
        txProvider.startDate, txProvider.endDate);
    final grossProfit = txProvider.totalProfit;
    final netProfit = grossProfit - periodExpenses;

    // Calculate Payment Methods Breakdown
    final Map<String, double> paymentBreakdown = {};
    for (final tx in completedTx) {
      if (tx.payments.isNotEmpty) {
        for (final p in tx.payments) {
          paymentBreakdown[p.method] =
              (paymentBreakdown[p.method] ?? 0.0) + p.amount;
        }
      } else {
        paymentBreakdown[tx.paymentMethod] =
            (paymentBreakdown[tx.paymentMethod] ?? 0.0) + tx.total;
      }
    }

    // Calculate Sales per Cashier
    final Map<String, double> cashierSales = {};
    for (final tx in completedTx) {
      final name = tx.cashierName.isEmpty ? 'Kasir' : tx.cashierName;
      cashierSales[name] = (cashierSales[name] ?? 0.0) + tx.total;
    }

    // Calculate Top Products & Dead Stock
    final Map<String, int> productSalesQty = {};
    final Set<String> soldProductIds = {};
    for (final tx in completedTx) {
      for (final item in tx.items) {
        productSalesQty[item.productName] =
            (productSalesQty[item.productName] ?? 0) + item.quantity;
        soldProductIds.add(item.productId);
      }
    }
    final sortedTopProducts = productSalesQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedTopProducts.take(5).toList();

    final deadStockProducts = prodProvider.products
        .where((p) => !soldProductIds.contains(p.id))
        .take(8)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Laporan & Analitik Keuangan'),
      ),
      drawer: const AdminDrawer(currentRoute: 'reports'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'reports'),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.containerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip(context, 'today', 'Hari Ini', txProvider),
                      _buildChip(
                          context, 'week', 'Minggu Ini (7 Hari)', txProvider),
                      _buildChip(context, 'month', 'Bulan Ini', txProvider),
                      _buildChip(context, 'all', 'Semua Waktu', txProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Profit & Financial Summary (with Net Profit deducting Expenses)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 50),
                  child: _buildMainProfitCard(
                    context,
                    txProvider,
                    grossProfit: grossProfit,
                    expenses: periodExpenses,
                    netProfit: netProfit,
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary Metrics Grid
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Builder(
                    builder: (context) {
                      final width = MediaQuery.of(context).size.width;
                      final isDesktop = width >= 900;
                      final isTablet = width >= 600 && width < 900;
                      final isLandscape = MediaQuery.of(context).orientation ==
                          Orientation.landscape;
                      final crossAxisCount =
                          isDesktop ? 4 : (isTablet || isLandscape ? 4 : 2);

                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 98,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        children: [
                        _buildMetricCard(
                          'Total Modal / HPP',
                          AnimatedCurrencyText(
                            value: txProvider.totalCost,
                            style: AppTheme.numericStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.primary,
                            ),
                          ),
                          Icons.account_balance_wallet_outlined,
                          AppTheme.primary,
                        ),
                        _buildMetricCard(
                          'Pengeluaran Toko',
                          AnimatedCurrencyText(
                            value: periodExpenses,
                            style: AppTheme.numericStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.error,
                            ),
                          ),
                          Icons.trending_down_rounded,
                          AppTheme.error,
                        ),
                        _buildMetricCard(
                          'Total Transaksi',
                          AnimatedCountText(
                            count: completedTx.length,
                            suffix: ' Nota',
                            style: AppTheme.numericStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.secondary,
                            ),
                          ),
                          Icons.receipt_long_rounded,
                          AppTheme.secondary,
                        ),
                        _buildMetricCard(
                          'Produk Terjual',
                          AnimatedCountText(
                            count: txProvider.totalItemsSold,
                            suffix: ' Item',
                            style: AppTheme.numericStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          Icons.inventory_2_outlined,
                          const Color(0xFF0284C7),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Payment Methods Breakdown
              FadeSlideIn(
                delay: const Duration(milliseconds: 190),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metode Pembayaran',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: paymentBreakdown.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Belum ada transaksi pada periode ini',
                                  style: TextStyle(color: AppTheme.outline),
                                ),
                              ),
                            )
                          : Column(
                              children: paymentBreakdown.entries.map((entry) {
                                final percent = txProvider.totalRevenue > 0
                                    ? (entry.value / txProvider.totalRevenue) *
                                        100
                                    : 0.0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusDefault),
                                        ),
                                        child: const Icon(
                                          Icons.payments_rounded,
                                          size: 17,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(
                                                entry.value),
                                            style: AppTheme.numericSmallStyle
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${percent.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppTheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Sales per Cashier Breakdown (PRD Section 5.5)
              if (cashierSales.isNotEmpty) ...[
                Text(
                  'Penjualan per Kasir',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: cashierSales.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 18, color: AppTheme.secondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(entry.value),
                              style: AppTheme.numericSmallStyle.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // Top 5 Products
              FadeSlideIn(
                delay: const Duration(milliseconds: 260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 5 Produk Terlaris',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: top5.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Belum ada produk terjual pada periode ini',
                                  style: TextStyle(color: AppTheme.outline),
                                ),
                              ),
                            )
                          : Column(
                              children: top5.asMap().entries.map((entry) {
                                final rank = entry.key + 1;
                                final item = entry.value;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: rank == 1
                                            ? AppTheme.secondaryContainer
                                            : AppTheme.surfaceContainerLow,
                                        child: Text(
                                          '$rank',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: rank == 1
                                                ? AppTheme.onSecondaryContainer
                                                : AppTheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm),
                                        ),
                                        child: Text(
                                          '${item.value} terjual',
                                          style: AppTheme.numericSmallStyle
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Dead Stock / Unsold Products (PRD Section 5.5)
              if (deadStockProducts.isNotEmpty) ...[
                Text(
                  'Produk Tidak Laku / Dead Stock (Periode Ini)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: deadStockProducts
                        .map((p) => Chip(
                              label: Text(
                                '${p.name} (Stok: ${p.stock})',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              backgroundColor: AppTheme.surfaceContainerLow,
                            ))
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildChip(BuildContext context, String range, String label,
      TransactionProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => provider.setQuickDateFilter(range),
      ),
    );
  }

  Widget _buildMainProfitCard(
    BuildContext context,
    TransactionProvider provider, {
    required double grossProfit,
    required double expenses,
    required double netProfit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'TOTAL OMSET / PENJUALAN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCurrencyText(
              value: provider.totalRevenue,
              style: AppTheme.numericLargeStyle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LABA BERSIH (OMSET - HPP - PENGELUARAN)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedCurrencyText(
                        value: netProfit,
                        style: AppTheme.numericStyle.copyWith(
                          color: netProfit >= 0
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Laba Kotor: ${CurrencyFormatter.format(grossProfit)} • Beban: -${CurrencyFormatter.format(expenses)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: netProfit >= 0 ? AppTheme.secondary : AppTheme.error,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  netProfit >= 0 ? 'LABA BERSIH' : 'DEFISIT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, Widget valueWidget, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
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
