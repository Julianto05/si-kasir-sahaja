import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shift_model.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/transaction_provider.dart';
import 'shift_receipt_dialog.dart';

/// Shift Closing Dialog (Tutup Kasir ala Indomaret/Retail POS).
///
/// Features system sales recap, physical cash denomination counting,
/// variance indicator, and shift closing receipt generation.
class ShiftClosingDialog extends StatefulWidget {
  final ShiftModel shift;

  const ShiftClosingDialog({super.key, required this.shift});

  static Future<void> show(BuildContext context, ShiftModel shift) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftClosingDialog(shift: shift),
    );
  }

  @override
  State<ShiftClosingDialog> createState() => _ShiftClosingDialogState();
}

class _ShiftClosingDialogState extends State<ShiftClosingDialog> {
  final Map<int, TextEditingController> _denominationControllers = {
    100000: TextEditingController(text: '0'),
    50000: TextEditingController(text: '0'),
    20000: TextEditingController(text: '0'),
    10000: TextEditingController(text: '0'),
    5000: TextEditingController(text: '0'),
    2000: TextEditingController(text: '0'),
    1000: TextEditingController(text: '0'),
  };

  final TextEditingController _coinsController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final c in _denominationControllers.values) {
      c.dispose();
    }
    _coinsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalPhysicalCash {
    double total = 0.0;
    _denominationControllers.forEach((val, controller) {
      final qty = int.tryParse(controller.text) ?? 0;
      total += val * qty;
    });
    final coins = double.tryParse(_coinsController.text) ?? 0.0;
    total += coins;
    return total;
  }

  Map<String, int> get _denominationMap {
    final map = <String, int>{};
    _denominationControllers.forEach((val, controller) {
      final qty = int.tryParse(controller.text) ?? 0;
      if (qty > 0) {
        map[val.toString()] = qty;
      }
    });
    final coins = int.tryParse(_coinsController.text) ?? 0;
    if (coins > 0) {
      map['coins'] = coins;
    }
    return map;
  }

  Future<void> _handleConfirmClosing(
      double cashSales, double expectedCash) async {
    final shiftProvider = context.read<ShiftProvider>();
    final txProvider = context.read<TransactionProvider>();

    // Shift transactions: filter transactions created between openedAt and now by this cashier
    final shiftTxs = txProvider.allTransactions.where((tx) {
      final isCashier = tx.cashierId == widget.shift.cashierId ||
          tx.cashierName == widget.shift.cashierName;
      final afterOpen = tx.createdAt.isAfter(
          widget.shift.openedAt.subtract(const Duration(minutes: 1)));
      return isCashier && afterOpen && tx.isCompleted;
    }).toList();

    setState(() => _isSubmitting = true);

    final closedShift = await shiftProvider.closeCurrentShift(
      shiftTransactions: shiftTxs,
      physicalCash: _totalPhysicalCash,
      denominations: _denominationMap,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (closedShift != null) {
        Navigator.pop(context); // Close closing dialog
        ShiftReceiptDialog.show(context, closedShift); // Open Receipt
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shiftProvider.errorMessage ?? 'Gagal melakukan closing shift',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    // Shift transactions matching current shift period
    final shiftTxs = txProvider.allTransactions.where((tx) {
      final isCashier = tx.cashierId == widget.shift.cashierId ||
          tx.cashierName == widget.shift.cashierName;
      final afterOpen = tx.createdAt.isAfter(
          widget.shift.openedAt.subtract(const Duration(minutes: 1)));
      return isCashier && afterOpen && tx.isCompleted;
    }).toList();

    double cashSales = 0.0;
    double nonCashSales = 0.0;
    for (final tx in shiftTxs) {
      if (tx.paymentMethod == 'cash') {
        cashSales += tx.total;
      } else {
        nonCashSales += tx.total;
      }
    }

    final totalSales = cashSales + nonCashSales;
    final expectedCash = widget.shift.startingCash + cashSales;
    final physicalCash = _totalPhysicalCash;
    final variance = physicalCash - expectedCash;

    final openTimeStr =
        DateFormat('dd MMM yyyy, HH:mm').format(widget.shift.openedAt);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tutup Shift Kasir (Closing)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Kasir: ${widget.shift.cashierName} • Buka: $openTimeStr',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ─── Content Body ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. System Sales Recap Card
                    _buildSectionTitle('1. Rekapitulasi Sistem', Icons.analytics_outlined),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildRecapRow('Modal Awal Kasir',
                              widget.shift.startingCash, isMuted: true),
                          _buildRecapRow('Penjualan Tunai (Cash)', cashSales),
                          _buildRecapRow(
                              'Penjualan Non-Tunai (QRIS/EDC)', nonCashSales),
                          const Divider(height: 16),
                          _buildRecapRow('Total Omset Shift', totalSales,
                              isBold: true, color: AppTheme.primary),
                          _buildRecapRow(
                              'Jumlah Transaksi', shiftTxs.length.toDouble(),
                              isCount: true),
                          const Divider(height: 16),
                          _buildRecapRow(
                            'Wajib Ada di Laci (Modal + Tunai)',
                            expectedCash,
                            isBold: true,
                            color: AppTheme.secondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Physical Cash Calculator (Denominasi)
                    _buildSectionTitle(
                        '2. Hitung Fisik Uang Kas (Laci Kasir)',
                        Icons.payments_outlined),
                    const SizedBox(height: 4),
                    const Text(
                      'Hitung dan masukkan jumlah lembar uang fisik di laci kasir saat ini:',
                      style: TextStyle(fontSize: 11, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 10),

                    // Denomination Inputs Grid
                    ...[100000, 50000, 20000, 10000, 5000, 2000, 1000]
                        .map((denom) => _buildDenominationInput(denom)),

                    // Coins input
                    _buildCoinsInput(),

                    const SizedBox(height: 14),

                    // 3. Live Variance Indicator Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: variance == 0
                            ? AppTheme.secondary.withValues(alpha: 0.1)
                            : (variance < 0
                                ? AppTheme.error.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: variance == 0
                              ? AppTheme.secondary
                              : (variance < 0 ? AppTheme.error : Colors.blue),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL FISIK KAS:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(physicalCash),
                                style: AppTheme.numericStyle.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                variance == 0
                                    ? 'STATUS: SEIMBANG (MATCH)'
                                    : (variance < 0
                                        ? 'STATUS: SELISIH KURANG (MINUS)'
                                        : 'STATUS: SELISIH LEBIH (PLUS)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: variance == 0
                                      ? AppTheme.secondary
                                      : (variance < 0
                                          ? AppTheme.error
                                          : Colors.blue.shade700),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(variance),
                                style: AppTheme.numericStyle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: variance == 0
                                      ? AppTheme.secondary
                                      : (variance < 0
                                          ? AppTheme.error
                                          : Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4. Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Penutupan Shift (Opsional)',
                        hintText:
                            'e.g. Laci seimbang, ada pergantian kasir sore...',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Footer Action ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _handleConfirmClosing(
                              cashSales, expectedCash),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Konfirmasi & Cetak Struk',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecapRow(String label, double amount,
      {bool isBold = false,
      bool isMuted = false,
      bool isCount = false,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMuted ? AppTheme.outline : AppTheme.onSurface,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            isCount ? '${amount.toInt()} Nota' : CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? (isMuted ? AppTheme.outline : AppTheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationInput(int value) {
    final controller = _denominationControllers[value]!;
    final qty = int.tryParse(controller.text) ?? 0;
    final subtotal = value * qty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              CurrencyFormatter.format(value.toDouble()),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('x', style: TextStyle(color: AppTheme.outline)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(color: AppTheme.outline)),
          const Spacer(),
          Text(
            CurrencyFormatter.format(subtotal.toDouble()),
            style: AppTheme.numericSmallStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: subtotal > 0 ? AppTheme.primary : AppTheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsInput() {
    final coins = double.tryParse(_coinsController.text) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Text(
              'Uang Koin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Total nominal koin (Rp)',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.format(coins),
            style: AppTheme.numericSmallStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: coins > 0 ? AppTheme.primary : AppTheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
