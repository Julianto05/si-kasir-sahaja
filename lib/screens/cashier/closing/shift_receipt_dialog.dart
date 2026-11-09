import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shift_model.dart';
import '../../../providers/store_settings_provider.dart';

/// Thermal Receipt Dialog Preview for Shift Closing (Struk Rekap Penutupan Kasir).
class ShiftReceiptDialog extends StatelessWidget {
  final ShiftModel shift;

  const ShiftReceiptDialog({super.key, required this.shift});

  static Future<void> show(BuildContext context, ShiftModel shift) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShiftReceiptDialog(shift: shift),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>().settings;
    final openStr = DateFormat('dd/MM/yyyy HH:mm').format(shift.openedAt);
    final closeStr = shift.closedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(shift.closedAt!)
        : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final isBalanced = shift.cashDifference == 0;
    final isShortage = shift.cashDifference < 0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Struk Rekap Penutupan Kasir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Thermal Paper Content (White Background)
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Store Header
                      Text(
                        settings.storeName.isNotEmpty
                            ? settings.storeName
                            : AppConstants.appName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (settings.storeAddress.isNotEmpty)
                        Text(
                          settings.storeAddress,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        '================================',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'LAPORAN TUTUP SHIFT KASIR',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        '================================',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Metadata
                      _buildReceiptRow('Kasir', shift.cashierName),
                      _buildReceiptRow(
                        'ID Shift',
                        shift.id.substring(0, 8).toUpperCase(),
                      ),
                      _buildReceiptRow('Buka Shift', openStr),
                      _buildReceiptRow('Tutup Shift', closeStr),
                      const SizedBox(height: 6),
                      const Text(
                        '--------------------------------',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Sales Breakdown
                      _buildReceiptRow(
                        'Modal Awal',
                        CurrencyFormatter.format(shift.startingCash),
                      ),
                      _buildReceiptRow(
                        'Penjualan Tunai',
                        CurrencyFormatter.format(shift.cashSales),
                      ),
                      _buildReceiptRow(
                        'Penjualan Non-Tunai',
                        CurrencyFormatter.format(shift.nonCashSales),
                      ),
                      _buildReceiptRow(
                        'Total Omset Shift',
                        CurrencyFormatter.format(shift.totalSales),
                        isBold: true,
                      ),
                      _buildReceiptRow(
                        'Jumlah Transaksi',
                        '${shift.transactionCount} Transaksi',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '--------------------------------',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Cashier Drawer Reconciliation (Termasuk Modal Awal)
                      _buildReceiptRow(
                        'Total Kas Wajib di Laci',
                        CurrencyFormatter.format(shift.expectedCash),
                        isBold: true,
                      ),
                      _buildReceiptRow(
                        'Fisik Kas Dihitung',
                        CurrencyFormatter.format(shift.physicalCash),
                        isBold: true,
                      ),
                      const SizedBox(height: 4),

                      // Variance Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isBalanced
                              ? Colors.green.shade50
                              : (isShortage
                                    ? Colors.red.shade50
                                    : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isBalanced
                                ? Colors.green
                                : (isShortage ? Colors.red : Colors.blue),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isBalanced
                                  ? 'SELISIH (MATCH)'
                                  : (isShortage
                                        ? 'SELISIH (MINUS)'
                                        : 'SELISIH (PLUS)'),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isBalanced
                                    ? Colors.green.shade800
                                    : (isShortage
                                          ? Colors.red.shade800
                                          : Colors.blue.shade800),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(shift.cashDifference),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isBalanced
                                    ? Colors.green.shade800
                                    : (isShortage
                                          ? Colors.red.shade800
                                          : Colors.blue.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Denominations Breakdown
                      if (shift.denominations.isNotEmpty) ...[
                        const Text(
                          'Rincian Pecahan Uang Fisik:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ...shift.denominations.entries.map((e) {
                          if (e.key == 'coins') {
                            return _buildReceiptRow(
                              '• Koin',
                              CurrencyFormatter.format(e.value.toDouble()),
                            );
                          }
                          final val = int.tryParse(e.key) ?? 0;
                          return _buildReceiptRow(
                            '• ${CurrencyFormatter.format(val.toDouble())}',
                            '${e.value} lbr = ${CurrencyFormatter.format((val * e.value).toDouble())}',
                          );
                        }),
                        const SizedBox(height: 6),
                      ],

                      // Non-Cash Reconciliation Section
                      if (shift.nonCashSales > 0 || shift.physicalNonCash > 0) ...[
                        const Text(
                          '--------------------------------',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.black38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Rekonsiliasi Non-Tunai (Slip/EDC):',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        _buildReceiptRow(
                          'Sistem Non-Tunai',
                          CurrencyFormatter.format(shift.nonCashSales),
                        ),
                        _buildReceiptRow(
                          'Fisik Bukti Transfer/EDC',
                          '${shift.nonCashReceiptCount} Slip = ${CurrencyFormatter.format(shift.physicalNonCash)}',
                          isBold: true,
                        ),
                        _buildReceiptRow(
                          'Selisih Slip Non-Tunai',
                          CurrencyFormatter.format(shift.nonCashDifference),
                          color: shift.nonCashDifference == 0
                              ? Colors.green.shade800
                              : (shift.nonCashDifference < 0
                                  ? Colors.red.shade800
                                  : Colors.blue.shade800),
                        ),
                        const SizedBox(height: 6),
                      ],

                      const Text(
                        '================================',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      _buildReceiptRow(
                        'TOTAL SETORAN KASIR',
                        CurrencyFormatter.format(shift.totalPhysicalIncome),
                        isBold: true,
                      ),
                      _buildReceiptRow(
                        '• Fisik Kas Tunai',
                        CurrencyFormatter.format(shift.physicalCash),
                      ),
                      if (shift.physicalNonCash > 0)
                        _buildReceiptRow(
                          '• Fisik Bukti Non-Tunai',
                          CurrencyFormatter.format(shift.physicalNonCash),
                        ),
                      const SizedBox(height: 6),

                      if (shift.notes.isNotEmpty) ...[
                        const Text(
                          'Catatan Kasir:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          shift.notes,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const Text(
                        '================================',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Signature columns (Kasir & Supervisor)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Kasir Shift,',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                '(${shift.cashierName})',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Column(
                            children: [
                              Text(
                                'Supervisor,',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                              SizedBox(height: 36),
                              Text(
                                '( .................... )',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Buttons
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mengirim struk rekap ke printer thermal...',
                            ),
                            backgroundColor: AppTheme.secondary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Cetak Struk'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Selesai'),
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

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
