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
import '../../widgets/motion_widgets.dart';
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

              context.read<PosProvider>().clearCart();
              await context.read<AuthProvider>().signOut();

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  SmoothPageRoute(page: const AuthGate()),
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
    final shiftProvider = context.read<ShiftProvider>();
    if (!shiftProvider.hasActiveShift) {
      final opened = await StartShiftDialog.show(context);
      if (opened != true) return;
    }

    if (!context.mounted) return;
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
            SmoothPageRoute(page: const PosScreen()),
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
        SmoothPageRoute(page: const PosScreen()),
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
              child: const Icon(Icons.storefront_rounded, size: 19),
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
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text(
          'Buka Kasir / POS',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Card: Cashier Shift Info ───────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: _buildShiftHeader(
                  context,
                  user?.name ?? 'Kasir',
                  todayStr,
                  myTodaySales,
                ),
              ),
              const SizedBox(height: 14),

              // ─── Shift Status & Closing Card (Ala Indomaret) ────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 110),
                child: _buildShiftControlCard(context, shiftProvider),
              ),
              const SizedBox(height: 18),

              // ─── Primary Quick Actions ────────────────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 170),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ScaleTap(
                        onTap: () => _openPos(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.secondaryGradient,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.point_of_sale_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Mulai Transaksi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ScaleTap(
                        onTap: () => _scanBarcodeQuick(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLowest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Scan',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ─── Today's Shift Performance Metrics ─────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 230),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Shift Hari Ini',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final width = MediaQuery.of(context).size.width;
                        final isDesktop = width >= 900;
                        final isTablet = width >= 600 && width < 900;
                        final crossAxisCount =
                            isDesktop ? 4 : (isTablet ? 2 : 2);
                        final aspectRatio =
                            isDesktop ? 1.8 : (isTablet ? 1.75 : 1.48);

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                          children: [
                            _buildMetricCard(
                              'Total Penjualan',
                              AnimatedCurrencyText(
                                value: myTodaySales,
                                style: AppTheme.numericSmallStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              Icons.payments_rounded,
                              AppTheme.secondary,
                              subtitle: 'Omset shift Anda',
                            ),
                            _buildMetricCard(
                              'Transaksi Sukses',
                              AnimatedCountText(
                                count: myTodayTx.length,
                                suffix: ' Nota',
                                style: AppTheme.numericSmallStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Icons.receipt_long_rounded,
                              AppTheme.primary,
                              subtitle: 'Pelanggan terlayani',
                            ),
                            _buildMetricCard(
                              'Item Terjual',
                              AnimatedCountText(
                                count: myTodayItems,
                                suffix: ' Pcs',
                                style: AppTheme.numericSmallStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              Icons.inventory_2_outlined,
                              const Color(0xFF0284C7),
                              subtitle: 'Total kuantitas barang',
                            ),
                            _buildMetricCard(
                              'Status Shift',
                              Text(
                                shiftProvider.hasActiveShift
                                    ? 'Shift Aktif'
                                    : 'Belum Buka',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: shiftProvider.hasActiveShift
                                      ? AppTheme.secondary
                                      : AppTheme.outline,
                                ),
                              ),
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
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ─── Recent Shift Transactions Feed ────────────────────
              FadeSlideIn(
                delay: const Duration(milliseconds: 290),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Nota Shift Ini',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            '${myTodayTx.length} Transaksi',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
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
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color:
                                AppTheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 36,
                                color: AppTheme.outline.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada transaksi di shift ini',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ketuk "Mulai Transaksi" di atas untuk melayani pelanggan pertama Anda.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.outline,
                              ),
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
                            onTap: () =>
                                TransactionDetailDialog.show(context, tx),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 76), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftHeader(
    BuildContext context,
    String name,
    String dateStr,
    double myTodaySales,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: AppTheme.secondary,
                    child: Text(
                      (name.isNotEmpty ? name[0] : 'K').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 17,
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
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
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
                      const SizedBox(height: 3),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftControlCard(
      BuildContext context, ShiftProvider shiftProvider) {
    final shift = shiftProvider.activeShift;
    final isOpen = shiftProvider.hasActiveShift && shift != null;

    final openTimeStr =
        isOpen ? DateFormat('HH:mm').format(shift.openedAt) : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOpen
            ? AppTheme.secondary.withValues(alpha: 0.07)
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isOpen
              ? AppTheme.secondary.withValues(alpha: 0.35)
              : AppTheme.outlineVariant.withValues(alpha: 0.8),
          width: isOpen ? 1.5 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOpen
                  ? AppTheme.secondary
                  : AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: isOpen ? Colors.white : AppTheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PulseIndicator(
                      color: isOpen ? AppTheme.secondary : AppTheme.warning,
                      size: 7,
                      active: isOpen,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isOpen
                            ? 'Shift Sedang Berjalan'
                            : 'Shift Belum Dibuka',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color:
                              isOpen ? AppTheme.secondary : AppTheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isOpen
                      ? 'Buka: $openTimeStr • Modal: ${CurrencyFormatter.format(shift.startingCash)}'
                      : 'Buka shift & masukkan modal awal laci kasir.',
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
              label: const Text(
                'Tutup',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => StartShiftDialog.show(context),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text(
                'Buka Shift',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
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
    Widget valueWidget,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              valueWidget,
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: AppTheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

    return ScaleTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: const Icon(
                Icons.receipt_rounded,
                color: AppTheme.secondary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.invoiceNumber,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$timeStr • ${transaction.items.length} Item • ${transaction.paymentMethod.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(transaction.total),
              style: AppTheme.numericSmallStyle.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
