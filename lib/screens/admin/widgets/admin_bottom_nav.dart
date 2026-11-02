import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/motion_widgets.dart';
import '../../pos/pos_screen.dart';
import '../admin_dashboard_screen.dart';
import '../product/product_list_screen.dart';
import '../report/report_screen.dart';
import '../transaction/transaction_list_screen.dart';

/// Modern Mobile Bottom Navigation Bar for Admin screens.
///
/// Features 4 primary tabs (Beranda, Produk, Transaksi, Laporan) plus a
/// prominent center "Kasir POS" dock button for instant mobile checkout access.
/// Automatically hides on tablet/desktop (`width >= 700`) where the Drawer
/// and wider layout take over.
class AdminBottomNav extends StatelessWidget {
  final String currentRoute;

  const AdminBottomNav({
    super.key,
    required this.currentRoute,
  });

  void _navigateTo(BuildContext context, String route, Widget screen) {
    if (currentRoute == route) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacement(
      SmoothPageRoute(page: screen),
    );
  }

  void _openPos(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      SmoothPageRoute(page: const PosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 700) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTabItem(
                  icon: Icons.grid_view_rounded,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Beranda',
                  isSelected: currentRoute == 'dashboard',
                  onTap: () => _navigateTo(
                    context,
                    'dashboard',
                    const AdminDashboardScreen(),
                  ),
                ),
                _NavTabItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Produk',
                  isSelected: currentRoute == 'products',
                  onTap: () => _navigateTo(
                    context,
                    'products',
                    const ProductListScreen(),
                  ),
                ),

                // Center Prominent POS Button
                ScaleTap(
                  onTap: () => _openPos(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.secondaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.point_of_sale_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Kasir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _NavTabItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Transaksi',
                  isSelected: currentRoute == 'transactions',
                  onTap: () => _navigateTo(
                    context,
                    'transactions',
                    const TransactionListScreen(),
                  ),
                ),
                _NavTabItem(
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Laporan',
                  isSelected: currentRoute == 'reports',
                  onTap: () => _navigateTo(
                    context,
                    'reports',
                    const ReportScreen(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: isSelected ? AppTheme.primary : AppTheme.outline,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

