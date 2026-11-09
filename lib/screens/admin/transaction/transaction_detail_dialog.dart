import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/finance_model.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../pos/receipt_dialog.dart';

/// Modal dialog displaying full transaction details with receivable installment history.
/// Only contains the 'Cetak Struk' button as requested.
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

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt);
    final isCompleted = tx.isCompleted;
    final isUnpaid = tx.isUnpaid;
    final isCancelled = tx.isCancelled;

    final isDebtTx =
        isUnpaid ||
        tx.paymentMethod.toLowerCase() == 'piutang' ||
        tx.payments.any((p) => p.method.toLowerCase() == 'piutang') ||
        (tx.paidAmount < tx.total);

    final financeProvider = context.watch<FinanceProvider>();
    final debt = financeProvider.findDebtByInvoice(tx.invoiceNumber);
    final payments = debt != null
        ? financeProvider.getPaymentsForDebt(debt.id)
        : <DebtPaymentModel>[];

    final isLunasFromDebt = (debt != null && debt.isPaid) || isCompleted;
    final isActualUnpaid = !isCancelled && !isLunasFromDebt &&
        (isUnpaid || debt != null || tx.paymentMethod.toLowerCase() == 'piutang');

    final effectivePaid = debt != null
        ? (tx.total - debt.remainingAmount).clamp(0.0, tx.total)
        : tx.paidAmount;
    final effectiveRemaining = debt != null
        ? debt.remainingAmount
        : (tx.total - tx.paidAmount).clamp(0.0, double.infinity);

    String statusText;
    Color statusBg;
    Color statusFg;

    if (isCancelled) {
      statusText = 'Dibatalkan / Refund';
      statusBg = AppTheme.errorContainer;
      statusFg = AppTheme.onErrorContainer;
    } else if (isLunasFromDebt) {
      statusText = 'Lunas';
      statusBg = AppTheme.secondaryContainer;
      statusFg = AppTheme.secondary;
    } else if (debt != null && debt.paidAmount > 0) {
      statusText = 'Dicicil (Sisa: ${CurrencyFormatter.format(debt.remainingAmount)})';
      statusBg = Colors.amber.withValues(alpha: 0.2);
      statusFg = Colors.amber[900]!;
    } else if (isActualUnpaid) {
      statusText = 'Belum Lunas (Piutang)';
      statusBg = Colors.amber.withValues(alpha: 0.2);
      statusFg = Colors.amber[900]!;
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.containerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.outline,
                        ),
                      ),
                    ],
                    if (tx.cancelReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Alasan Batal: ${tx.cancelReason}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.error,
                        ),
                      ),
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
                          'Total Tagihan',
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
                    _buildRow(
                      isDebtTx ? 'Total Telah Dibayar (DP + Cicilan)' : 'Nominal Bayar',
                      effectivePaid,
                    ),
                    _buildRow(
                      isActualUnpaid ? 'Sisa Piutang Saat Ini' : 'Kembalian',
                      isActualUnpaid ? effectiveRemaining : tx.changeAmount,
                    ),

                    // Riwayat Cicilan Piutang Section
                    if (isDebtTx) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.history_edu_rounded,
                            size: 18,
                            color: Colors.amber[900],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Informasi & Riwayat Cicilan Piutang',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[900],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Card Data Pengutang
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              'Nama Pengutang',
                              tx.customerName ??
                                  (debt?.partyName.isNotEmpty == true
                                      ? debt!.partyName
                                      : 'Pelanggan Umum'),
                            ),
                            if ((tx.customerPhone != null &&
                                    tx.customerPhone!.isNotEmpty) ||
                                (debt?.phone.isNotEmpty == true))
                              _buildInfoRow(
                                'No. WhatsApp / HP',
                                tx.customerPhone ?? debt!.phone,
                              ),
                            if ((tx.customerAddress != null &&
                                    tx.customerAddress!.isNotEmpty) ||
                                (debt?.address.isNotEmpty == true))
                              _buildInfoRow(
                                'Alamat',
                                tx.customerAddress ?? debt!.address,
                              ),
                            if (debt?.dueDate != null)
                              _buildInfoRow(
                                'Jatuh Tempo',
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(debt!.dueDate!),
                              ),
                            _buildInfoRow(
                              'Total Tagihan Nota',
                              CurrencyFormatter.format(tx.total),
                            ),
                            _buildInfoRow(
                              'Total Cicilan Masuk (Keuangan)',
                              CurrencyFormatter.format(debt?.paidAmount ?? 0),
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isLunasFromDebt
                                      ? 'Status Pembayaran:'
                                      : 'Sisa Piutang Saat Ini:',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  isLunasFromDebt
                                      ? 'LUNAS'
                                      : CurrencyFormatter.format(effectiveRemaining),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isLunasFromDebt
                                        ? AppTheme.secondary
                                        : Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // List Cicilan
                      Text(
                        'Daftar Pembayaran Cicilan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (payments.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppTheme.outline,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Belum ada pembayaran cicilan untuk piutang ini.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...payments.map((p) {
                          final pDate = DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(p.date);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              border: Border.all(
                                color: AppTheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pDate,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Metode: ${p.method}${p.createdByName.isNotEmpty ? " • Kasir: ${p.createdByName}" : ""}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (p.note.isNotEmpty)
                                        Text(
                                          'Catatan: ${p.note}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontStyle: FontStyle.italic,
                                            color: AppTheme.outline,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+${CurrencyFormatter.format(p.amount)}',
                                  style: AppTheme.numericSmallStyle.copyWith(
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer: Hanya ada tombol 'Cetak Struk'
            Padding(
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.touchTarget,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ReceiptDialog.show(
                      context,
                      tx.copyWith(items: _items ?? []),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 20),
                  label: const Text(
                    'Cetak Struk',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.outline),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11.5)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
