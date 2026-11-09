import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../pos/receipt_dialog.dart';

/// Modal dialog displaying full transaction details with refund capabilities.
class TransactionDetailDialog extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailDialog({super.key, required this.transaction});

  static Future<void> show(BuildContext context, TransactionModel transaction) {
    return showDialog(
      context: context,
      builder: (ctx) => TransactionDetailDialog(transaction: transaction),
    );
  }

  @override
  State<TransactionDetailDialog> createState() =>
      _TransactionDetailDialogState();
}

class _TransactionDetailDialogState extends State<TransactionDetailDialog> {
  List<TransactionItemModel>? _items;
  bool _isLoadingItems = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction.items.isNotEmpty) {
      _items = widget.transaction.items;
    } else {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _isLoadingItems = true);
    final items = await context.read<TransactionProvider>().getTransactionItems(
      widget.transaction.id,
    );
    if (mounted) {
      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _handleChangeStatus() async {
    final tx = widget.transaction;

    // Jika belum lunas, berikan dialog konfirmasi langsung ubah ke Lunas
    if (tx.isUnpaid) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konfirmasi Status Lunas'),
          content: Text(
            'Ubah status transaksi ${tx.invoiceNumber} menjadi LUNAS?\n\n'
            'Status transaksi akan berubah menjadi Lunas dan piutang di menu Pengeluaran & Keuangan juga otomatis menjadi LUNAS.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ubah ke Lunas'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final success = await context
            .read<TransactionProvider>()
            .updateTransactionStatus(
              transaction: tx,
              newStatus: AppConstants.statusCompleted,
            );

        if (!mounted) return;

        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status transaksi ${tx.invoiceNumber} berhasil diubah menjadi LUNAS!',
              ),
              backgroundColor: AppTheme.secondary,
            ),
          );
        }
      }
      return;
    }

    // Jika sudah lunas atau status lain, berikan pilihan untuk ubah status
    String selectedStatus = tx.status;
    final chosenStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ubah Status Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nota: ${tx.invoiceNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih status transaksi. Status piutang di menu Pengeluaran & Keuangan akan otomatis tersinkronisasi.',
                style: TextStyle(fontSize: 12, color: AppTheme.outline),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Transaksi',
                  prefixIcon: Icon(Icons.sync_alt_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.statusCompleted,
                    child: Text('Lunas (Selesai)'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.statusUnpaid,
                    child: Text('Belum Lunas'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedStatus = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedStatus),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (chosenStatus != null && chosenStatus != tx.status && mounted) {
      final success = await context
          .read<TransactionProvider>()
          .updateTransactionStatus(transaction: tx, newStatus: chosenStatus);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status transaksi ${tx.invoiceNumber} berhasil diubah menjadi ${chosenStatus == AppConstants.statusCompleted ? "LUNAS" : "BELUM LUNAS"}!',
            ),
            backgroundColor: chosenStatus == AppConstants.statusCompleted
                ? AppTheme.secondary
                : Colors.amber[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt);
    final isCompleted = tx.isCompleted;
    final isUnpaid = tx.isUnpaid;
    final isCancelled = tx.isCancelled;

    String statusText;
    Color statusBg;
    Color statusFg;

    if (isCompleted) {
      statusText = 'Lunas';
      statusBg = AppTheme.secondaryContainer;
      statusFg = AppTheme.secondary;
    } else if (isUnpaid) {
      statusText = 'Belum Lunas';
      statusBg = Colors.amber.withValues(alpha: 0.2);
      statusFg = Colors.amber[900]!;
    } else if (isCancelled) {
      statusText = 'Dibatalkan / Refund';
      statusBg = AppTheme.errorContainer;
      statusFg = AppTheme.onErrorContainer;
    } else {
      statusText = 'Ditahan (Hold)';
      statusBg = Colors.blue.withValues(alpha: 0.2);
      statusFg = Colors.blue[900]!;
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.invoiceNumber,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Cashier & Payment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Kasir: ${tx.cashierName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Metode: ${tx.paymentMethod}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (tx.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Catatan: ${tx.notes}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
              if (tx.cancelReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Alasan Batal: ${tx.cancelReason}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                ),
              ],
              const SizedBox(height: 12),

              // Items Section
              Text(
                'Rincian Produk',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_isLoadingItems)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_items != null)
                ..._items!.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.price)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: AppTheme.numericSmallStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Totals
              _buildRow('Subtotal', tx.subtotal),
              if (tx.discount > 0)
                _buildRow('Diskon', -tx.discount, isDiscount: true),
              if (tx.tax > 0) _buildRow('Pajak (PPN)', tx.tax),
              if (tx.serviceCharge > 0)
                _buildRow('Service Charge', tx.serviceCharge),
              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyFormatter.format(tx.total),
                    style: AppTheme.numericStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildRow('Nominal Bayar', tx.paidAmount),
              _buildRow('Kembalian', tx.changeAmount),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ReceiptDialog.show(
                          context,
                          tx.copyWith(items: _items ?? []),
                        );
                      },
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cetak Struk'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleChangeStatus,
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tx.isUnpaid ? 'Ubah ke Lunas' : 'Ubah Status',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tx.isUnpaid
                            ? AppTheme.secondary
                            : AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDiscount ? AppTheme.error : AppTheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              color: isDiscount ? AppTheme.error : AppTheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
