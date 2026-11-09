import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shift_model.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/pos_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/transaction_provider.dart';
import 'shift_receipt_dialog.dart';

/// Shift Closing Dialog (Tutup Kasir ala Indomaret/Retail POS - PRD Section 5.3).
///
/// Features system sales recap, manual petty cash in/out, physical cash denomination counting,
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

  final TextEditingController _coinsController = TextEditingController(
    text: '0',
  );
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
      final text = controller.text
          .replaceAll('.', '')
          .replaceAll(',', '')
          .trim();
      final qty = int.tryParse(text) ?? 0;
      total += val * qty;
    });
    final coins = CurrencyFormatter.parse(_coinsController.text);
    total += coins;
    return total;
  }

  Map<String, int> get _denominationMap {
    final map = <String, int>{};
    _denominationControllers.forEach((val, controller) {
      final text = controller.text
          .replaceAll('.', '')
          .replaceAll(',', '')
          .trim();
      final qty = int.tryParse(text) ?? 0;
      if (qty > 0) {
        map[val.toString()] = qty;
      }
    });
    final coins = CurrencyFormatter.parse(_coinsController.text).toInt();
    if (coins > 0) {
      map['coins'] = coins;
    }
    return map;
  }

  List<TransactionModel> _getShiftTransactions(List<TransactionModel> allTxs) {
    return allTxs.where((tx) {
      if (tx.isCancelled) return false;

      // 1. Exact match with shift id
      if (tx.shiftId != null &&
          tx.shiftId!.isNotEmpty &&
          tx.shiftId == widget.shift.id) {
        return true;
      }

      // 2. Fallback: match by cashier and time window with 5 min tolerance
      final isCashier =
          (tx.cashierId.isNotEmpty && tx.cashierId == widget.shift.cashierId) ||
          (tx.cashierName.isNotEmpty &&
              tx.cashierName.toLowerCase() ==
                  widget.shift.cashierName.toLowerCase());

      final openTolerance = widget.shift.openedAt.subtract(
        const Duration(minutes: 5),
      );
      final closeTolerance = widget.shift.closedAt != null
          ? widget.shift.closedAt!.add(const Duration(minutes: 5))
          : DateTime.now().add(const Duration(minutes: 5));

      final withinWindow =
          tx.createdAt.isAfter(openTolerance) &&
          tx.createdAt.isBefore(closeTolerance);

      final hasOtherShiftId =
          tx.shiftId != null &&
          tx.shiftId!.isNotEmpty &&
          tx.shiftId != widget.shift.id;

      if (!hasOtherShiftId &&
          (isCashier || widget.shift.cashierId.isEmpty) &&
          withinWindow) {
        return true;
      }

      return false;
    }).toList();
  }

  Future<void> _handleConfirmClosing(
    double cashSales,
    double expectedCash,
  ) async {
    var physicalCash = _totalPhysicalCash;

    // Peringatan jika kasir belum memasukkan rincian fisik sama sekali (fisik = 0 padahal sistem > 0)
    if (physicalCash == 0 && expectedCash > 0) {
      final confirmZero = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Konfirmasi Hitungan Kas', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Anda belum memasukkan rincian uang fisik di laci kasir (Total Fisik: Rp 0).\n\nApakah Anda ingin mengisi rincian uang fisik terlebih dahulu?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), // Lanjut dengan Rp 0
              child: const Text('Tetap Lanjut (Fisik Rp 0)'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(ctx, false), // Kembali untuk mengisi
              child: const Text('Hitung Uang Fisik'),
            ),
          ],
        ),
      );

      if (confirmZero != true) {
        return; // Kasir memilih kembali untuk mengisi uang fisik
      }
    }

    var variance = physicalCash - expectedCash;

    // Jika terjadi minus, kasir HARUS menutupi minusnya terlebih dahulu!
    if (variance < 0) {
      final minusNominal = variance.abs();
      final covered = await _showMinusCoverDialog(minusNominal);
      if (covered != true || !mounted) {
        return; // Dibatalkan, jangan tutup shift sebelum minus tertutupi
      }
      // Perbarui nilai fisik kas setelah talangan ditambahkan
      physicalCash = _totalPhysicalCash;
      variance = physicalCash - expectedCash;
      if (variance < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fisik kas masih kurang ${CurrencyFormatter.format(variance.abs())}. Minus wajib ditutupi penuh sebelum closing.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final shiftProvider = context.read<ShiftProvider>();
    final txProvider = context.read<TransactionProvider>();

    final shiftTxs = _getShiftTransactions(txProvider.allTransactions);

    setState(() => _isSubmitting = true);

    final closedShift = await shiftProvider.closeCurrentShift(
      shiftTransactions: shiftTxs,
      physicalCash: physicalCash,
      denominations: _denominationMap,
      notes: _notesController.text.trim(),
      shiftId: widget.shift.id,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (closedShift != null) {
        // Clear POS cart so that stale items do not leak into the next shift
        context.read<PosProvider>().clearCart();
        Navigator.pop(context);
        ShiftReceiptDialog.show(context, closedShift);
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

  /// Popup dialog ketika fisik kas kurang (minus), mewajibkan kasir menutupi kekurangan.
  Future<bool?> _showMinusCoverDialog(double minusNominal) async {
    final coverCtrl = TextEditingController(
      text: CurrencyFormatter.formatCompact(minusNominal),
    );
    final noteCtrl = TextEditingController(
      text: 'Talangan kasir untuk menutupi selisih minus closing',
    );

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.error,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kas Minus / Selisih Kurang!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terjadi kekurangan fisik kas sebesar ${CurrencyFormatter.format(minusNominal)}.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sebelum menutup shift kasir, kasir wajib menutupi minus tersebut agar saldo kas seimbang/pertanggungjawaban tercatat.',
                style: TextStyle(fontSize: 12, color: AppTheme.outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: coverCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nominal Setoran / Talangan Kasir',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.price_check_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Penutup Minus',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hitung Ulang'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Setor Talangan & Lanjutkan'),
            onPressed: () {
              final coveredAmount = CurrencyFormatter.parse(coverCtrl.text);
              if (coveredAmount < minusNominal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Nominal talangan minimal ${CurrencyFormatter.format(minusNominal)} untuk menutupi seluruh kekurangan kas.',
                    ),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }

              // Tambahkan catatan pertanggungjawaban talangan kasir
              final currentNotes = _notesController.text.trim();
              final addInfo =
                  '[Minus Ditutupi Kasir: ${CurrencyFormatter.format(coveredAmount)} - ${noteCtrl.text.trim()}]';
              _notesController.text = currentNotes.isEmpty
                  ? addInfo
                  : '$currentNotes | $addInfo';

              // Tambahkan ke uang koin / fisik kas agar seimbang
              final currentCoins = CurrencyFormatter.parse(
                _coinsController.text,
              );
              final newCoins = currentCoins + coveredAmount;
              _coinsController.text = CurrencyFormatter.formatCompact(newCoins);

              setState(() {});
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final shiftTxs = _getShiftTransactions(txProvider.allTransactions);

    final breakdown = ShiftSalesBreakdown.compute(shiftTxs);
    final cashSales = breakdown.cashSales;
    final nonCashSales = breakdown.nonCashSales;
    final unpaidSales = breakdown.unpaidSales;
    final totalSales = breakdown.totalSales;

    final manualCashIn = widget.shift.totalCashIn;
    final manualCashOut = widget.shift.totalCashOut;
    final expectedCash =
        widget.shift.startingCash + cashSales + manualCashIn - manualCashOut;
    final physicalCash = _totalPhysicalCash;
    final variance = physicalCash - expectedCash;

    final openTimeStr = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(widget.shift.openedAt);

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
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    _buildSectionTitle(
                      '1. Rekapitulasi Sistem',
                      Icons.analytics_outlined,
                    ),
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
                          _buildRecapRow(
                            'Modal Awal Kasir',
                            widget.shift.startingCash,
                            isMuted: true,
                          ),
                          _buildRecapRow(
                            'Penjualan Tunai (Kas Masuk)',
                            cashSales,
                          ),
                          _buildRecapRow(
                            'Penjualan Non-Tunai (QRIS/EDC)',
                            nonCashSales,
                          ),
                          if (unpaidSales > 0)
                            _buildRecapRow(
                              'Penjualan Belum Lunas (Piutang)',
                              unpaidSales,
                              color: Colors.amber.shade900,
                            ),
                          if (manualCashIn > 0)
                            _buildRecapRow(
                              'Kas Masuk Manual (Petty Cash)',
                              manualCashIn,
                              color: AppTheme.secondary,
                            ),
                          if (manualCashOut > 0)
                            _buildRecapRow(
                              'Kas Keluar Manual (Petty Cash)',
                              -manualCashOut,
                              color: AppTheme.error,
                            ),
                          const Divider(height: 16),
                          _buildRecapRow(
                            'Total Omset Shift',
                            totalSales,
                            isBold: true,
                            color: AppTheme.primary,
                          ),
                          _buildRecapRow(
                            'Jumlah Transaksi',
                            shiftTxs.length.toDouble(),
                            isCount: true,
                          ),
                          const Divider(height: 16),
                          _buildRecapRow(
                            'Wajib Ada di Laci (Sistem)',
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
                      Icons.payments_outlined,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hitung dan masukkan jumlah lembar uang fisik di laci kasir saat ini:',
                      style: TextStyle(fontSize: 11, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 10),

                    // Denomination Inputs Grid
                    ...[
                      100000,
                      50000,
                      20000,
                      10000,
                      5000,
                      2000,
                      1000,
                    ].map((denom) => _buildDenominationInput(denom)),

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
                              const Expanded(
                                child: Text(
                                  'TOTAL FISIK KAS:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                              Expanded(
                                child: Text(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () =>
                                _handleConfirmClosing(cashSales, expectedCash),
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

  Widget _buildRecapRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isMuted = false,
    bool isCount = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isMuted ? AppTheme.outline : AppTheme.onSurface,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCount
                ? '${amount.toInt()} Nota'
                : CurrencyFormatter.format(amount),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(value.toDouble()),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
    final coins = CurrencyFormatter.parse(_coinsController.text);

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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  hintText: 'Total nominal koin (Rp)',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
