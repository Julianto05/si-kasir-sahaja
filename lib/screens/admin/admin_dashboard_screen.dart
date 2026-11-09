import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/motion_widgets.dart';
import '../cashier/closing/start_shift_dialog.dart';
import '../pos/pos_screen.dart';
import 'finance/finance_management_screen.dart';
import 'product/product_form_screen.dart';
import 'product/product_list_screen.dart';
import 'purchase/purchase_management_screen.dart';
import 'report/report_screen.dart';
import 'stock/stock_management_screen.dart';
import 'transaction/transaction_detail_dialog.dart';
import 'transaction/transaction_list_screen.dart';
import 'widgets/admin_bottom_nav.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/payment_donut_chart.dart';
import 'widgets/sales_trend_chart.dart';

/// Admin Dashboard Screen displaying live business metrics, animated charts,
/// and quick mobile-first navigation.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _openPos(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    if (auth.currentUser != null) {
      await shiftProvider.loadActiveShift(auth.currentUser!.id);
    }
    if (!context.mounted) return;
    if (!shiftProvider.hasActiveShift) {
      final opened = await StartShiftDialog.show(context);
      if (opened != true) return;
    }

    if (context.mounted) {
      Navigator.push(context, SmoothPageRoute(page: const PosScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.storefront_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale_rounded),
            tooltip: 'Buka Kasir POS',
            onPressed: () => _openPos(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'dashboard'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'dashboard'),
      floatingActionButton: isWide
          ? FloatingActionButton.extended(
              onPressed: () => _openPos(context),
              backgroundColor: AppTheme.secondary,
              icon: const Icon(Icons.point_of_sale_rounded),
              label: const Text('Buka Kasir / POS'),
            )
          : null,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.containerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Hero Banner
                FadeSlideIn(
                  delay: const Duration(milliseconds: 40),
                  child: _buildWelcomeBanner(
                    context,
                    user?.name ?? 'Admin',
                    txProvider.todayTransactionCount,
                  ),
                ),
                const SizedBox(height: 18),

                // Overview Cards (Penjualan Hari Ini, Pengeluaran Hari Ini, Stok & Expired, Produk)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 110),
                  child: _buildOverviewGrid(context, txProvider),
                ),
                const SizedBox(height: 16),

                // Expiry / Empty Stock Alert Banner (PRD Section 5.5)
                _buildInventoryAlertBanner(context),
                const SizedBox(height: 20),

                // Quick Actions Section
                FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aksi Cepat',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActions(context),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Visual Analytics Charts (Responsive for Mobile, Tablet & Desktop)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Builder(
                    builder: (context) {
                      final isDesktop = width >= 900;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: SalesTrendChart(
                                transactions: txProvider.allTransactions,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: PaymentDonutChart(
                                transactions: txProvider.allTransactions,
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          SalesTrendChart(
                            transactions: txProvider.allTransactions,
                          ),
                          const SizedBox(height: 14),
                          PaymentDonutChart(
                            transactions: txProvider.allTransactions,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Recent Transactions Section
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildRecentTransactions(context, txProvider),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(
    BuildContext context,
    String name,
    int todayTxCount,
  ) {
    final todayStr = DateFormatter.formatFullDate(DateTime.now());

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Stack(
        children: [
          // Decorative ambient circles
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -36,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withValues(alpha: 0.18),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PulseIndicator(
                            color: Color(0xFF34D399),
                            size: 7,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            todayStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Halo, $name 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayTxCount > 0
                      ? 'Toko aktif melayani $todayTxCount transaksi hari ini. Pantau stok & laporan secara real-time.'
                      : 'Kelola produk, stok, kategori, dan pantau performa toko Anda hari ini.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(
    BuildContext context,
    TransactionProvider txProvider,
  ) {
    final financeProv = context.watch<FinanceProvider>();
    final prodProvider = context.watch<ProductProvider>();
    final prodCount = prodProvider.products.length;
    final lowStockCount = prodProvider.lowStockCount;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && width < 900;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final crossAxisCount = isDesktop ? 4 : (isTablet || isLandscape ? 4 : 2);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 112,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _StatCard(
          title: 'Penjualan Hari Ini',
          icon: Icons.payments_rounded,
          color: AppTheme.secondary,
          valueWidget: AnimatedCurrencyText(
            value: txProvider.todaySales,
            style: AppTheme.numericStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.secondary,
            ),
          ),
          subtitle: '${txProvider.todayTransactionCount} transaksi sukses',
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(page: const ReportScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Pengeluaran Hari Ini',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFD97706),
          valueWidget: AnimatedCurrencyText(
            value: financeProv.todayExpenses,
            style: AppTheme.numericStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD97706),
            ),
          ),
          subtitle: 'Biaya operasional toko',
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(page: const FinanceManagementScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Stok Menipis / Kosong',
          icon: Icons.warning_amber_rounded,
          color: lowStockCount > 0 ? AppTheme.error : AppTheme.outline,
          showPulse: lowStockCount > 0,
          valueWidget: AnimatedCountText(
            count: lowStockCount,
            suffix: ' Produk',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: lowStockCount > 0 ? AppTheme.error : AppTheme.outline,
            ),
          ),
          subtitle: lowStockCount > 0 ? 'Perlu restock segera' : 'Stok aman',
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(page: const StockManagementScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Total Produk Aktif',
          icon: Icons.inventory_2_rounded,
          color: AppTheme.primary,
          valueWidget: AnimatedCountText(
            count: prodCount,
            suffix: ' Item',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          subtitle: 'Katalog terdaftar',
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(page: const ProductListScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInventoryAlertBanner(BuildContext context) {
    final prodProvider = context.watch<ProductProvider>();
    final expiring = prodProvider.expiringOrExpiredProducts;
    final emptyStock = prodProvider.products
        .where((p) => p.stock <= 0)
        .toList();

    if (expiring.isEmpty && emptyStock.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ScaleTap(
        onTap: () {
          Navigator.push(
            context,
            SmoothPageRoute(page: const StockManagementScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const PulseIndicator(color: AppTheme.error, size: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Peringatan Inventori: ${emptyStock.length} produk stok kosong & ${expiring.length} produk hampir/sudah kedaluwarsa.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onErrorContainer,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppTheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.point_of_sale_rounded,
            label: 'Kasir POS',
            color: AppTheme.secondary,
            onTap: () => _openPos(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_box_rounded,
            label: 'Produk Baru',
            color: AppTheme.primary,
            onTap: () => ProductFormScreen.navigate(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.warehouse_rounded,
            label: 'Atur Stok',
            color: const Color(0xFF0284C7),
            onTap: () {
              Navigator.push(
                context,
                SmoothPageRoute(page: const StockManagementScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.local_shipping_rounded,
            label: 'Pembelian',
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.push(
                context,
                SmoothPageRoute(page: const PurchaseManagementScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    TransactionProvider txProvider,
  ) {
    final recent = txProvider.allTransactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaksi Terbaru',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  SmoothPageRoute(page: const TransactionListScreen()),
                );
              },
              icon: const Text('Lihat Semua'),
              label: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppTheme.outline.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Belum ada transaksi penjualan.',
                  style: TextStyle(
                    color: AppTheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = recent[index];
              final timeStr = DateFormat('dd MMM, HH:mm').format(tx.createdAt);

              return ScaleTap(
                onTap: () => TransactionDetailDialog.show(context, tx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tx.isCompleted
                              ? AppTheme.secondary.withValues(alpha: 0.1)
                              : (tx.isUnpaid
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : AppTheme.errorContainer),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusDefault,
                          ),
                        ),
                        child: Icon(
                          tx.isCompleted
                              ? Icons.receipt_rounded
                              : (tx.isUnpaid
                                    ? Icons.pending_actions_rounded
                                    : Icons.cancel_outlined),
                          color: tx.isCompleted
                              ? AppTheme.secondary
                              : (tx.isUnpaid
                                    ? Colors.amber[900]
                                    : AppTheme.error),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    tx.invoiceNumber,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (tx.isUnpaid) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                    ),
                                    child: Text(
                                      'Belum Lunas',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tx.cashierName} • ${tx.paymentMethod} • $timeStr',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(tx.total),
                        style: AppTheme.numericSmallStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: tx.isCompleted
                              ? AppTheme.primary
                              : (tx.isUnpaid
                                    ? Colors.amber[900]
                                    : AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget valueWidget;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool showPulse;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.valueWidget,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.showPulse = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: showPulse
                ? AppTheme.error.withValues(alpha: 0.45)
                : AppTheme.outlineVariant.withValues(alpha: 0.7),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueWidget,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (showPulse) ...[
                      const PulseIndicator(color: AppTheme.error, size: 6),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: showPulse ? AppTheme.error : AppTheme.outline,
                          fontWeight: showPulse
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
