import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/store_settings_provider.dart';
import 'receipt_dialog.dart';

/// Checkout and payment dialog for POS cashier transactions.
class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CheckoutDialog(),
    );
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  late final TextEditingController _paidController;
  late final TextEditingController _discountController;
  late final TextEditingController _notesController;

  static const List<String> _methods = [
    'Cash',
    'QRIS',
    'Transfer',
    'Debit',
    'Kredit',
  ];

  @override
  void initState() {
    super.initState();
    final posProvider = context.read<PosProvider>();
    final settings = context.read<StoreSettingsProvider>().settings;
    final total = posProvider.calculateTotal(settings);

    // Default to exact amount for non-cash, or current paid amount
    posProvider.setPaidAmount(total);

    _paidController = TextEditingController(text: total.toInt().toString());
    _discountController = TextEditingController(
        text: posProvider.discount > 0
            ? posProvider.discount.toInt().toString()
            : '');
    _notesController = TextEditingController(text: posProvider.notes);
  }

  @override
  void dispose() {
    _paidController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setExactCash(double total) {
    setState(() {
      _paidController.text = total.toInt().toString();
      context.read<PosProvider>().setPaidAmount(total);
    });
  }

  void _addCash(double additional, double total) {
    final current =
        double.tryParse(_paidController.text.replaceAll('.', '')) ?? total;
    final newAmount = current + additional;
    setState(() {
      _paidController.text = newAmount.toInt().toString();
      context.read<PosProvider>().setPaidAmount(newAmount);
    });
  }

  Future<void> _handleCompleteTransaction() async {
    final posProvider = context.read<PosProvider>();
    final authProvider = context.read<AuthProvider>();
    final settings = context.read<StoreSettingsProvider>().settings;
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi kasir tidak valid. Silakan login.')),
      );
      return;
    }

    posProvider.setNotes(_notesController.text.trim());

    final completedTx = await posProvider.checkout(
      cashier: user,
      settings: settings,
    );

    if (!mounted) return;

    if (completedTx != null) {
      Navigator.of(context).pop(); // Close checkout dialog
      ReceiptDialog.show(context, completedTx); // Open receipt
    } else if (posProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(posProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = context.watch<PosProvider>();
    final settings = context.watch<StoreSettingsProvider>().settings;
    final total = posProvider.calculateTotal(settings);
    final change = posProvider.calculateChange(settings);

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
                  Text(
                    'Pembayaran',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: posProvider.isProcessing
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total Payable Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL TAGIHAN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(total),
                      style: AppTheme.numericLargeStyle.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (posProvider.discount > 0 ||
                        posProvider.calculateTax(settings) > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Subtotal: ${CurrencyFormatter.format(posProvider.subtotal)}'
                        '${posProvider.discount > 0 ? " • Diskon: -${CurrencyFormatter.format(posProvider.discount)}" : ""}'
                        '${posProvider.calculateTax(settings) > 0 ? " • PPN: +${CurrencyFormatter.format(posProvider.calculateTax(settings))}" : ""}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Methods
              Text(
                'Metode Pembayaran',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _methods.map((method) {
                    final isSelected = posProvider.paymentMethod == method;
                    IconData icon;
                    switch (method) {
                      case 'Cash':
                        icon = Icons.payments_rounded;
                        break;
                      case 'QRIS':
                        icon = Icons.qr_code_2_rounded;
                        break;
                      case 'Transfer':
                        icon = Icons.account_balance_rounded;
                        break;
                      default:
                        icon = Icons.credit_card_rounded;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: isSelected ? Colors.white : AppTheme.primary,
                        ),
                        label: Text(method),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            posProvider.setPaymentMethod(method);
                            if (method != 'Cash') {
                              _setExactCash(total);
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Cash Nominal & Fast Buttons (If Cash)
              if (posProvider.paymentMethod == 'Cash') ...[
                Text(
                  'Nominal Uang Diterima',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (val) {
                    final amount = double.tryParse(val) ?? 0.0;
                    posProvider.setPaidAmount(amount);
                  },
                ),
                const SizedBox(height: 8),

                // Quick Cash Buttons
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Uang Pas'),
                      onPressed: () => _setExactCash(total),
                    ),
                    ActionChip(
                      label: const Text('+10.000'),
                      onPressed: () => _addCash(10000, total),
                    ),
                    ActionChip(
                      label: const Text('+20.000'),
                      onPressed: () => _addCash(20000, total),
                    ),
                    ActionChip(
                      label: const Text('+50.000'),
                      onPressed: () => _addCash(50000, total),
                    ),
                    ActionChip(
                      label: const Text('+100.000'),
                      onPressed: () => _addCash(100000, total),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Change Display Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? AppTheme.secondaryContainer.withValues(alpha: 0.4)
                        : AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kembalian:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: change >= 0
                              ? AppTheme.onSecondaryContainer
                              : AppTheme.error,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(change),
                        style: AppTheme.numericStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: change >= 0
                              ? AppTheme.secondary
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Transaksi (Opsional)',
                  hintText: 'e.g. Meja 4 / Take Away / Nama Pelanggan',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                height: AppTheme.touchTarget,
                child: ElevatedButton.icon(
                  onPressed: posProvider.isProcessing ||
                          (posProvider.paidAmount < total)
                      ? null
                      : _handleCompleteTransaction,
                  icon: posProvider.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    posProvider.isProcessing
                        ? 'Memproses...'
                        : 'Selesaikan & Cetak Struk',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
