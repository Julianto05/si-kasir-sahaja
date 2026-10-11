import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/transaction_provider.dart';
import '../pos/pos_screen.dart';
import 'category/category_list_screen.dart';
import 'product/product_form_screen.dart';
import 'product/product_list_screen.dart';
import 'report/report_screen.dart';
import 'stock/stock_management_screen.dart';
import 'transaction/transaction_list_screen.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/payment_donut_chart.dart';
import 'widgets/sales_trend_chart.dart';

/// Admin Dashboard Screen displaying live business metrics and quick navigation.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();

              // Clear cart
              context.read<PosProvider>().clearCart();

              // Sign out from Firebase
              await context.read<AuthProvider>().signOut();

              // Navigate directly to AuthGate (LoginScreen)
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale_rounded),
            tooltip: 'Buka Kasir POS',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PosScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'dashboard'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PosScreen()),
          );
        },
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('Buka Kasir / POS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildWelcomeBanner(context, user?.name ?? 'Admin'),
              const SizedBox(height: AppTheme.spacingLg),

              // Overview Cards (Produk, Kategori, Stok Menipis, Penjualan Hari Ini)
              _buildOverviewGrid(context, txProvider),
              const SizedBox(height: AppTheme.spacingLg),

              // Visual Analytics Charts (Tablet & Desktop only: width >= 600)
              Builder(
                builder: (context) {
                  final width = MediaQuery.of(context).size.width;
                  if (width < 600) return const SizedBox.shrink();

                  final isDesktop = width >= 900;
                  return Column(
                    children: [
                      if (isDesktop)
                        Row(
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
                        )
                      else ...[
                        SalesTrendChart(
                          transactions: txProvider.allTransactions,
                        ),
                        const SizedBox(height: 16),
                        PaymentDonutChart(
                          transactions: txProvider.allTransactions,
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacingLg),
                    ],
                  );
                },
              ),

              // Quick Actions Section
              Text(
                'Aksi Cepat',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: AppTheme.spacingLg),

              // Recent Transactions Section
              _buildRecentTransactions(context, txProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang kembali,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Kelola produk, stok, kategori, dan transaksi toko Anda secara efisien.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(
      BuildContext context, TransactionProvider txProvider) {
    final catCount = context.watch<CategoryProvider>().allCategories.length;
    final prodCount = context.watch<ProductProvider>().allProducts.length;
    final lowStockCount = context.watch<ProductProvider>().lowStockCount;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && width < 900;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final aspectRatio = isDesktop ? 1.8 : (isTablet ? 1.6 : 1.45);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        _StatCard(
          title: 'Penjualan Hari Ini',
          value: CurrencyFormatter.format(txProvider.todaySales),
          icon: Icons.payments_rounded,
          color: AppTheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Total Produk',
          value: '$prodCount Item',
          icon: Icons.inventory_2_rounded,
          color: AppTheme.primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductListScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Stok Menipis',
          value: '$lowStockCount Produk',
          icon: Icons.warning_amber_rounded,
          color: lowStockCount > 0 ? AppTheme.error : AppTheme.outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const StockManagementScreen()),
            );
          },
        ),
        _StatCard(
          title: 'Kategori',
          value: '$catCount Kategori',
          icon: Icons.category_rounded,
          color: AppTheme.tertiary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryListScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.point_of_sale_rounded,
            label: 'Buka POS',
            color: AppTheme.secondary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PosScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_shopping_cart_rounded,
            label: 'Tambah Produk',
            color: AppTheme.primary,
            onTap: () => ProductFormScreen.navigate(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.receipt_long_rounded,
            label: 'Transaksi',
            color: AppTheme.primaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TransactionListScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, TransactionProvider txProvider) {
    final recent = txProvider.allTransactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaksi Terbaru',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionListScreen()),
                );
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Center(
              child: Text(
                'Belum ada transaksi penjualan.',
                style: TextStyle(color: AppTheme.outline),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final tx = recent[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  border: Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${tx.cashierName} • ${tx.paymentMethod}',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.outline),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(tx.total),
                      style: AppTheme.numericSmallStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tx.isCompleted
                            ? AppTheme.secondary
                            : AppTheme.error,
                      ),
                    ),
                  ],
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
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  Icon(icon, size: 20, color: color),
                ],
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        minimumSize: Size.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
