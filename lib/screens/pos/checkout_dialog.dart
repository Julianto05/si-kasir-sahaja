import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/store_settings_provider.dart';
import 'receipt_dialog.dart';

/// Checkout and payment dialog for POS cashier transactions (PRD Section 5.2 - Split Payment, Loyalty Points, Piutang).
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
  late final TextEditingController _notesController;

  // Status transaksi: 'completed' (Lunas) atau 'unpaid' (Belum Lunas)
  String _transactionStatus = AppConstants.statusCompleted;

  // Split Payment state
  bool _isSplitPayment = false;
  String _splitMethod1 = 'Cash';
  String _splitMethod2 = 'QRIS';
  late final TextEditingController _splitAmount1Ctrl;
  late final TextEditingController _splitAmount2Ctrl;

  @override
  void initState() {
    super.initState();
    final posProvider = context.read<PosProvider>();
    final settings = context.read<StoreSettingsProvider>().settings;
    final total = posProvider.calculateTotal(settings);

    posProvider.setPaidAmount(total);
    posProvider.clearSplitPayments();

    _paidController = TextEditingController(
      text: CurrencyFormatter.formatCompact(total),
    );
    _notesController = TextEditingController(text: posProvider.notes);

    final half = (total / 2).roundToDouble();
    _splitAmount1Ctrl = TextEditingController(
      text: CurrencyFormatter.formatCompact(half),
    );
    _splitAmount2Ctrl = TextEditingController(
      text: CurrencyFormatter.formatCompact(total - half),
    );
  }

  @override
  void dispose() {
    _paidController.dispose();
    _notesController.dispose();
    _splitAmount1Ctrl.dispose();
    _splitAmount2Ctrl.dispose();
    super.dispose();
  }

  void _syncSplitPayments() {
    final amt1 = CurrencyFormatter.parse(_splitAmount1Ctrl.text);
    final amt2 = CurrencyFormatter.parse(_splitAmount2Ctrl.text);
    context.read<PosProvider>().setSplitPayments([
      PaymentSplitItem(method: _splitMethod1, amount: amt1),
      PaymentSplitItem(method: _splitMethod2, amount: amt2),
    ]);
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

    if (_isSplitPayment) {
      _syncSplitPayments();
    }

    posProvider.setNotes(_notesController.text.trim());

    final shiftProvider = context.read<ShiftProvider>();
    if (!shiftProvider.hasActiveShift || shiftProvider.activeShift == null) {
      await shiftProvider.loadActiveShift(user.id);
    }

    if (!shiftProvider.hasActiveShift || shiftProvider.activeShift == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transaksi ditolak: Shift kasir tidak aktif. Silakan buka shift terlebih dahulu.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final completedTx = await posProvider.checkout(
      cashier: user,
      settings: settings,
      status: _transactionStatus,
      shiftId: shiftProvider.activeShift!.id,
    );

    if (!mounted) return;

    if (completedTx != null) {
      Navigator.of(context).pop();
      ReceiptDialog.show(context, completedTx);
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
    final totalDiscount = posProvider.calculateTotalDiscount(settings);
    final customer = posProvider.selectedCustomer;

    final methods = <String>[
      ...settings.activePaymentMethods,
      if (customer != null &&
          !settings.activePaymentMethods.contains('Piutang'))
        'Piutang',
    ];

    // Status Belum Lunas jika dipilih atau pembayaran via Piutang
    final isUnpaid =
        _transactionStatus == AppConstants.statusUnpaid ||
        posProvider.paymentMethod == 'Piutang';

    // Nilai sisa belum bayar
    final unpaidBalance = (total - posProvider.paidAmount).clamp(
      0.0,
      double.infinity,
    );

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
                    'Pembayaran Kasir',
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
              const SizedBox(height: 8),

              // Total Payable Box
              Container(
                padding: const EdgeInsets.all(14),
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
                    const SizedBox(height: 4),
                    Text(
                      'Subtotal: ${CurrencyFormatter.format(posProvider.subtotal)}'
                      '${totalDiscount > 0 ? " • Diskon: -${CurrencyFormatter.format(totalDiscount)}" : ""}'
                      '${posProvider.calculateTax(settings) > 0 ? " • PPN: +${CurrencyFormatter.format(posProvider.calculateTax(settings))}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Status Transaksi: Lunas vs Belum Lunas
              Text(
                'Status Transaksi',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      onTap: () {
                        setState(() {
                          _transactionStatus = AppConstants.statusCompleted;
                          _paidController.text =
                              CurrencyFormatter.formatCompact(total);
                          posProvider.setPaidAmount(total);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: !isUnpaid
                              ? AppTheme.secondary.withValues(alpha: 0.15)
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: !isUnpaid
                                ? AppTheme.secondary
                                : AppTheme.outlineVariant,
                            width: !isUnpaid ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: !isUnpaid
                                  ? AppTheme.secondary
                                  : AppTheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Lunas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !isUnpaid
                                    ? AppTheme.secondary
                                    : AppTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      onTap: () {
                        setState(() {
                          _transactionStatus = AppConstants.statusUnpaid;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isUnpaid
                              ? Colors.amber.withValues(alpha: 0.2)
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(
                            color: isUnpaid
                                ? Colors.amber[800]!
                                : AppTheme.outlineVariant,
                            width: isUnpaid ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              size: 18,
                              color: isUnpaid
                                  ? Colors.amber[900]
                                  : AppTheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Belum Lunas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isUnpaid
                                    ? Colors.amber[900]
                                    : AppTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Loyalty Point Redemption (if customer selected & has points)
              if (customer != null &&
                  settings.enableLoyaltyPoints &&
                  customer.points > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppTheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tukar ${customer.points} Poin Member (-${CurrencyFormatter.format(customer.points * settings.pointRedeemValue)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: posProvider.redeemedPoints > 0,
                        activeThumbColor: AppTheme.secondary,
                        onChanged: (val) {
                          posProvider.setRedeemedPoints(
                            val ? customer.points : 0,
                          );
                          final newTotal = posProvider.calculateTotal(settings);
                          if (!isUnpaid) {
                            _paidController.text =
                                CurrencyFormatter.formatCompact(newTotal);
                            posProvider.setPaidAmount(newTotal);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Split Payment Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Metode Pembayaran',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSplitPayment = !_isSplitPayment;
                        if (_isSplitPayment) {
                          final half = (total / 2).roundToDouble();
                          _splitAmount1Ctrl.text =
                              CurrencyFormatter.formatCompact(half);
                          _splitAmount2Ctrl.text =
                              CurrencyFormatter.formatCompact(total - half);
                          _syncSplitPayments();
                        } else {
                          posProvider.clearSplitPayments();
                          _paidController.text =
                              CurrencyFormatter.formatCompact(total);
                          posProvider.setPaidAmount(total);
                        }
                      });
                    },
                    icon: Icon(
                      _isSplitPayment
                          ? Icons.check_box_rounded
                          : Icons.call_split_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Split Payment (Kombinasi)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              if (_isSplitPayment) ...[
                // Split Payment UI dengan pemisah titik
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _splitMethod1,
                              decoration: const InputDecoration(
                                labelText: 'Metode 1',
                                isDense: true,
                              ),
                              items: settings.activePaymentMethods
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _splitMethod1 = v);
                                  _syncSplitPayments();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _splitAmount1Ctrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Nominal 1 (Rp)',
                                isDense: true,
                              ),
                              onChanged: (v) {
                                final a1 = CurrencyFormatter.parse(v);
                                final rem = (total - a1).clamp(
                                  0.0,
                                  double.infinity,
                                );
                                _splitAmount2Ctrl.text =
                                    CurrencyFormatter.formatCompact(rem);
                                _syncSplitPayments();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _splitMethod2,
                              decoration: const InputDecoration(
                                labelText: 'Metode 2',
                                isDense: true,
                              ),
                              items: settings.activePaymentMethods
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _splitMethod2 = v);
                                  _syncSplitPayments();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _splitAmount2Ctrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Nominal 2 (Rp)',
                                isDense: true,
                              ),
                              onChanged: (_) => _syncSplitPayments(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                // Single Payment Method Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: methods.map((method) {
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
                        case 'Piutang':
                          icon = Icons.pending_actions_rounded;
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
                            color: isSelected
                                ? Colors.white
                                : AppTheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              posProvider.setPaymentMethod(method);
                              if (method == 'Piutang') {
                                setState(() {
                                  _transactionStatus =
                                      AppConstants.statusUnpaid;
                                  _paidController.text = '0';
                                  posProvider.setPaidAmount(0);
                                });
                              } else {
                                if (!isUnpaid) {
                                  _paidController.text =
                                      CurrencyFormatter.formatCompact(total);
                                  posProvider.setPaidAmount(total);
                                }
                              }
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Cash / DP Nominal dengan Pemisah Titik Ribuan
                Text(
                  isUnpaid
                      ? 'Uang Muka / Nominal yang Sudah Dibayar (DP)'
                      : 'Nominal Uang Pembayaran',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (val) {
                    final amount = CurrencyFormatter.parse(val);
                    posProvider.setPaidAmount(amount);
                  },
                ),
                const SizedBox(height: 8),

                // Tampilan Kembalian (Lunas) atau Sisa Tagihan (Belum Lunas)
                if (isUnpaid) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusDefault,
                      ),
                      border: Border.all(color: Colors.amber[800]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Sisa Piutang / Belum Lunas:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(unpaidBalance),
                          style: AppTheme.numericStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // Change Display Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: change >= 0
                          ? AppTheme.secondaryContainer.withValues(alpha: 0.4)
                          : AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusDefault,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Kembalian:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: change >= 0
                                  ? AppTheme.onSecondaryContainer
                                  : AppTheme.error,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 14),
                ],
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
              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                height: AppTheme.touchTarget,
                child: ElevatedButton.icon(
                  onPressed:
                      posProvider.isProcessing ||
                          (!isUnpaid && posProvider.paidAmount < total)
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
                      : Icon(
                          isUnpaid
                              ? Icons.pending_actions_rounded
                              : Icons.check_circle_rounded,
                        ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      posProvider.isProcessing
                          ? 'Memproses...'
                          : (isUnpaid
                                ? 'Simpan Transaksi (Belum Lunas)'
                                : 'Selesaikan & Cetak Struk (Lunas)'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: isUnpaid
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          foregroundColor: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
