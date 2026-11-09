import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/motion_widgets.dart';

/// Modal dialog displaying a clean, thermal-style receipt preview with
/// animated success checkmark badge.
class ReceiptDialog extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  static Future<void> show(BuildContext context, TransactionModel transaction) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>().settings;
    final dateStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(transaction.createdAt);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated Top Success Check Icon
                const Center(child: AnimatedSuccessBadge(size: 52)),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    transaction.isUnpaid
                        ? 'Transaksi Tersimpan (Belum Lunas)'
                        : 'Transaksi Berhasil (Lunas)!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: transaction.isUnpaid
                          ? Colors.amber[900]
                          : AppTheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        settings.storeName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (settings.storeAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          settings.storeAddress,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (settings.storePhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Telp: ${settings.storePhone}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Dashed Line Divider
                _buildDashedLine(),
                const SizedBox(height: 12),

                // Transaction Meta
                _buildMetaRow('No. Nota', transaction.invoiceNumber),
                _buildMetaRow('Tanggal', dateStr),
                _buildMetaRow('Kasir', transaction.cashierName),
                if (transaction.customerName != null &&
                    transaction.customerName!.isNotEmpty)
                  _buildMetaRow('Pelanggan', transaction.customerName!),
                if (transaction.customerPhone != null &&
                    transaction.customerPhone!.isNotEmpty)
                  _buildMetaRow('No. HP', transaction.customerPhone!),
                if (transaction.customerAddress != null &&
                    transaction.customerAddress!.isNotEmpty)
                  _buildMetaRow('Alamat', transaction.customerAddress!),
                _buildMetaRow(
                  'Status',
                  transaction.isUnpaid ? 'Belum Lunas (Piutang)' : 'Lunas',
                ),
                _buildMetaRow('Metode', transaction.paymentMethod),
                const SizedBox(height: 12),

                _buildDashedLine(),
                const SizedBox(height: 12),

                // Items List
                ...transaction.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurface,
                              ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.price)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(item.subtotal),
                              style: AppTheme.numericSmallStyle.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                _buildDashedLine(),
                const SizedBox(height: 12),

                // Totals Breakdown
                _buildTotalRow('Subtotal', transaction.subtotal),
                if (transaction.discount > 0)
                  _buildTotalRow(
                    'Diskon',
                    -transaction.discount,
                    isDiscount: true,
                  ),
                if (transaction.tax > 0)
                  _buildTotalRow('Pajak (PPN)', transaction.tax),
                if (transaction.serviceCharge > 0)
                  _buildTotalRow('Service Charge', transaction.serviceCharge),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                      ),
                      Text(
                        CurrencyFormatter.format(transaction.total),
                        style: AppTheme.numericStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildTotalRow(
                  'Bayar (${transaction.paymentMethod})',
                  transaction.paidAmount,
                ),
                if (transaction.isUnpaid)
                  _buildTotalRow(
                    'Sisa Belum Bayar',
                    (transaction.total - transaction.paidAmount).clamp(
                      0.0,
                      double.infinity,
                    ),
                    isDiscount: true,
                  )
                else
                  _buildTotalRow(
                    'Kembalian',
                    transaction.changeAmount,
                    isChange: true,
                  ),
                const SizedBox(height: 16),

                _buildDashedLine(),
                const SizedBox(height: 12),

                // Receipt Footer
                Center(
                  child: Text(
                    settings.receiptFooter,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Struk berhasil dicetak'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Cetak'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Selesai'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.outline),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isChange = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDiscount ? AppTheme.error : Colors.black87,
                fontWeight: isChange ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              color: isDiscount
                  ? AppTheme.error
                  : (isChange ? AppTheme.secondary : Colors.black87),
              fontWeight: isChange ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.outlineVariant),
              ),
            );
          }),
        );
      },
    );
  }
}
