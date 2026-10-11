import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../main.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/barcode_scanner_modal.dart';
import '../admin/transaction/transaction_detail_dialog.dart';
import '../pos/pos_screen.dart';
import 'closing/shift_closing_dialog.dart';
import 'closing/start_shift_dialog.dart';

/// Modern Cashier Dashboard Screen tailored for cashier operational shifts.
class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.currentUser != null) {
          context.read<ShiftProvider>().loadActiveShift(auth.currentUser!.id);
        }
      }
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin mengakhiri sesi kasir?'),
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

  Future<void> _scanBarcodeQuick(BuildContext context) async {
    final barcode = await BarcodeScannerModal.show(context);
    if (barcode != null && barcode.isNotEmpty && context.mounted) {
      final product =
          await context.read<ProductProvider>().findByBarcode(barcode);
      if (product != null && context.mounted) {
        final added = context.read<PosProvider>().addToCart(product);
        if (added) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${product.name}" ditambahkan ke keranjang'),
              backgroundColor: AppTheme.secondary,
              duration: const Duration(seconds: 1),
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PosScreen()),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk dengan barcode "$barcode" tidak ditemukan'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openPos(BuildContext context) async {
    final shiftProvider = context.read<ShiftProvider>();
    if (!shiftProvider.hasActiveShift) {
      final opened = await StartShiftDialog.show(context);
      if (opened != true) return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PosScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final shiftProvider = context.watch<ShiftProvider>();
    final user = authProvider.currentUser;

    // Filter today's transactions for this cashier
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final myTodayTx = txProvider.allTransactions.where((tx) {
      final isMine = tx.cashierId == user?.id || tx.cashierName == user?.name;
      final isToday = tx.createdAt.isAfter(today);
      return isMine && isToday && tx.isCompleted;
    }).toList();

    // Summary calculations
    double myTodaySales = 0.0;
    int myTodayItems = 0;
    for (final tx in myTodayTx) {
      myTodaySales += tx.total;
      for (final item in tx.items) {
        myTodayItems += item.quantity;
      }
    }

    final todayStr = DateFormatter.formatFullDate(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.storefront_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kasir: ${user?.name ?? "User"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar dari Akun',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPos(context),
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.shopping_cart_checkout_rounded),
        label: const Text('Buka Kasir / POS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Card: Cashier Shift Info ───────────────────
              _buildShiftHeader(context, user?.name ?? 'Kasir', todayStr),
              const SizedBox(height: 14),

              // ─── Shift Status & Closing Card (Ala Indomaret) ────────
              _buildShiftControlCard(context, shiftProvider),
              const SizedBox(height: AppTheme.spacingLg),

              // ─── Primary Quick Actions ────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _openPos(context),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 22),
                      label: const Text(
                        'Mulai Transaksi',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _scanBarcodeQuick(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('Scan'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.primary),
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // ─── Today's Shift Performance Metrics ─────────────────
              Text(
                'Ringkasan Shift Hari Ini',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              Builder(
                builder: (context) {
                  final width = MediaQuery.of(context).size.width;
                  final isDesktop = width >= 900;
                  final isTablet = width >= 600 && width < 900;
                  final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
                  final aspectRatio = isDesktop ? 1.8 : (isTablet ? 1.6 : 1.45);

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: aspectRatio,
                    children: [
                      _buildMetricCard(
                        'Total Penjualan',
                        CurrencyFormatter.format(myTodaySales),
                        Icons.payments_rounded,
                        AppTheme.secondary,
                        subtitle: 'Omset shift Anda',
                      ),
                      _buildMetricCard(
                        'Transaksi Sukses',
                        '${myTodayTx.length} Nota',
                        Icons.receipt_long_rounded,
                        AppTheme.primary,
                        subtitle: 'Pelanggan terlayani',
                      ),
                      _buildMetricCard(
                        'Item Terjual',
                        '$myTodayItems Pcs',
                        Icons.inventory_2_outlined,
                        AppTheme.tertiary,
                        subtitle: 'Total kuantitas barang',
                      ),
                      _buildMetricCard(
                        'Status Shift',
                        shiftProvider.hasActiveShift ? 'Shift Aktif' : 'Belum Buka',
                        Icons.check_circle_rounded,
                        shiftProvider.hasActiveShift
                            ? AppTheme.secondary
                            : AppTheme.outline,
                        subtitle: shiftProvider.hasActiveShift
                            ? 'Siap melayani'
                            : 'Buka shift kasir',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // ─── Recent Shift Transactions Feed ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Nota Shift Ini',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${myTodayTx.length} Transaksi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (myTodayTx.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 48,
                        color: AppTheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada transaksi di shift ini',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Klik "Mulai Transaksi" di atas untuk melayani pelanggan.',
                        style: TextStyle(fontSize: 12, color: AppTheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myTodayTx.take(8).length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = myTodayTx[index];
                    return _CashierTxCard(
                      transaction: tx,
                      onTap: () => TransactionDetailDialog.show(context, tx),
                    );
                  },
                ),
              const SizedBox(height: 60), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftHeader(
      BuildContext context, String name, String dateStr) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF002D54),
            Color(0xFF00437A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondaryContainer,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.secondary,
                  child: Text(
                    (name.isNotEmpty ? name[0] : 'K').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
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
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Text(
                            'KASIR',
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
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftControlCard(
      BuildContext context, ShiftProvider shiftProvider) {
    final shift = shiftProvider.activeShift;
    final isOpen = shiftProvider.hasActiveShift && shift != null;

    final openTimeStr = isOpen
        ? DateFormat('HH:mm').format(shift.openedAt)
        : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOpen
            ? AppTheme.secondary.withValues(alpha: 0.08)
            : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isOpen
              ? AppTheme.secondary.withValues(alpha: 0.4)
              : AppTheme.outlineVariant.withValues(alpha: 0.6),
          width: isOpen ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOpen ? AppTheme.secondary : AppTheme.outlineVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                      ? 'Shift Sedang Berjalan'
                      : 'Shift Kasir Belum Dibuka',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOpen ? AppTheme.secondary : AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen
                      ? 'Buka: $openTimeStr • Modal Awal: ${CurrencyFormatter.format(shift.startingCash)}'
                      : 'Buka shift dan masukkan modal awal uang kembalian di laci kasir.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOpen)
            ElevatedButton.icon(
              onPressed: () => ShiftClosingDialog.show(context, shift),
              icon: const Icon(Icons.fact_check_rounded, size: 16),
              label: const Text('Tutup Kasir',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => StartShiftDialog.show(context),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Buka Shift',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTheme.numericSmallStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppTheme.outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CashierTxCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _CashierTxCard({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(transaction.createdAt);

    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.receipt_rounded,
                  color: AppTheme.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.invoiceNumber,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr • ${transaction.items.length} Item • ${transaction.paymentMethod.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(transaction.total),
                style: AppTheme.numericSmallStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
