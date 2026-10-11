import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/auth_provider.dart';
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
  bool _isRefunding = false;

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
    final items = await context
        .read<TransactionProvider>()
        .getTransactionItems(widget.transaction.id);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _handleRefund() async {
    final reasonController = TextEditingController();
    final shouldRefund = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembatalan / Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Membatalkan transaksi akan mengembalikan seluruh stok barang yang terjual.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan *',
                hintText: 'e.g. Pelanggan salah pesan / barang rusak',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Batalkan Transaksi'),
          ),
        ],
      ),
    );

    if (shouldRefund == true && mounted) {
      setState(() => _isRefunding = true);
      final admin = context.read<AuthProvider>().currentUser;
      if (admin == null) return;

      final success = await context.read<TransactionProvider>().cancelTransaction(
            transaction: widget.transaction,
            reason: reasonController.text.trim(),
            admin: admin,
          );

      if (!mounted) return;
      setState(() => _isRefunding = false);

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dibatalkan dan stok dikembalikan'),
            backgroundColor: AppTheme.secondary,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.invoiceNumber,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.outline),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.secondaryContainer
                          : AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      isCompleted ? 'Selesai' : 'Dibatalkan / Refund',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? AppTheme.onSecondaryContainer
                            : AppTheme.onErrorContainer,
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
                  Text('Kasir: ${tx.cashierName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Metode: ${tx.paymentMethod}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              if (tx.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Catatan: ${tx.notes}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              if (tx.cancelReason != null) ...[
                const SizedBox(height: 4),
                Text('Alasan Batal: ${tx.cancelReason}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.error)),
              ],
              const SizedBox(height: 12),

              // Items Section
              Text(
                'Rincian Produk',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.price)}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
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
                  const Text('Total Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                  OutlinedButton.icon(
                    onPressed: () {
                      ReceiptDialog.show(
                        context,
                        tx.copyWith(items: _items ?? []),
                      );
                    },
                    icon: const Icon(Icons.receipt_rounded, size: 18),
                    label: const Text('Cetak Struk'),
                  ),
                  const SizedBox(width: 8),
                  if (isCompleted)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRefunding ? null : _handleRefund,
                        icon: _isRefunding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text('Refund / Batalkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
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
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDiscount ? AppTheme.error : Colors.grey)),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              color: isDiscount ? AppTheme.error : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
