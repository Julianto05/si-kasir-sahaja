import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/product_provider.dart';
import '../../pos/pos_screen.dart';
import '../admin_dashboard_screen.dart';
import '../category/category_list_screen.dart';
import '../product/product_list_screen.dart';
import '../report/report_screen.dart';
import '../settings/store_settings_screen.dart';
import '../shift/shift_history_screen.dart';
import '../stock/stock_management_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../user/user_management_screen.dart';

/// Modern, elegantly styled Navigation Drawer for Admin in SiKasirSahaja POS.
class AdminDrawer extends StatelessWidget {
  final String currentRoute;

  const AdminDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final lowStockCount = context.watch<ProductProvider>().lowStockCount;

    return Drawer(
      backgroundColor: AppTheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            // ─── Modern Profile Header ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF001F3B),
                    Color(0xFF00386B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.secondaryContainer,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.secondary,
                      child: Text(
                        (user?.name.isNotEmpty == true ? user!.name[0] : 'A')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'admin@sikasirsahaja.com',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Text(
                            'ADMINISTRATOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Menu Items ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    isSelected: currentRoute == 'dashboard',
                    onTap: () => _navigate(context, const AdminDashboardScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.point_of_sale_rounded,
                    title: 'Kasir / POS',
                    isSelected: currentRoute == 'pos',
                    accentColor: AppTheme.secondary,
                    onTap: () => _navigate(context, const PosScreen()),
                  ),

                  const SizedBox(height: 8),
                  _buildSectionHeader('MASTER DATA'),

                  _buildMenuItem(
                    context,
                    icon: Icons.inventory_2_rounded,
                    title: 'Produk',
                    isSelected: currentRoute == 'products',
                    onTap: () => _navigate(context, const ProductListScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.category_rounded,
                    title: 'Kategori',
                    isSelected: currentRoute == 'categories',
                    onTap: () => _navigate(context, const CategoryListScreen()),
                  ),

                  const SizedBox(height: 8),
                  _buildSectionHeader('MANAJEMEN'),

                  _buildMenuItem(
                    context,
                    icon: Icons.warehouse_rounded,
                    title: 'Stok Barang',
                    isSelected: currentRoute == 'stock',
                    badge: lowStockCount > 0
                        ? '$lowStockCount menipis'
                        : null,
                    badgeColor: AppTheme.error,
                    onTap: () => _navigate(context, const StockManagementScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Semua Transaksi',
                    isSelected: currentRoute == 'transactions',
                    onTap: () =>
                        _navigate(context, const TransactionListScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_alt_rounded,
                    title: 'Pengguna / Kasir',
                    isSelected: currentRoute == 'users',
                    onTap: () => _navigate(context, const UserManagementScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.fact_check_rounded,
                    title: 'Rekap Closing Kasir',
                    isSelected: currentRoute == 'shifts',
                    onTap: () => _navigate(context, const ShiftHistoryScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.analytics_rounded,
                    title: 'Laporan Keuangan',
                    isSelected: currentRoute == 'reports',
                    onTap: () => _navigate(context, const ReportScreen()),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.storefront_rounded,
                    title: 'Pengaturan Toko',
                    isSelected: currentRoute == 'settings',
                    onTap: () => _navigate(context, const StoreSettingsScreen()),
                  ),
                ],
              ),
            ),

            // ─── Footer with App Info & Logout ───────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: AppTheme.error, size: 18),
                ),
                title: const Text(
                  'Keluar',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                trailing: Text(
                  'v${AppConstants.appVersion}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.outline),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.outline,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? AppTheme.primary;

    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.2)
                : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color: isSelected ? activeColor : AppTheme.onSurfaceVariant,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? activeColor : AppTheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppTheme.secondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        onTap: onTap,
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);

              // 1. Reset state in providers
              context.read<PosProvider>().clearCart();

              // 2. Sign out from Firebase
              await context.read<AuthProvider>().signOut();

              // 3. Reset entire navigation stack back to AuthGate
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
}
