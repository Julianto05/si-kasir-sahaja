import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';

/// Modal dialog for opening a cashier work shift with starting cash float.
class StartShiftDialog extends StatefulWidget {
  const StartShiftDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StartShiftDialog(),
    );
  }

  @override
  State<StartShiftDialog> createState() => _StartShiftDialogState();
}

class _StartShiftDialogState extends State<StartShiftDialog> {
  final TextEditingController _cashController =
      TextEditingController(text: '100.000');
  bool _isSubmitting = false;

  final List<double> _presetAmounts = [
    50000,
    100000,
    200000,
    300000,
    500000,
  ];

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _handleStartShift() async {
    final amount = CurrencyFormatter.parse(_cashController.text);
    if (amount < 0) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final shiftProvider = context.read<ShiftProvider>();

    final success = await shiftProvider.openShift(
      cashierId: auth.currentUser?.id ?? '',
      cashierName: auth.currentUser?.name ?? 'Kasir',
      startingCash: amount,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shift kasir berhasil dibuka dengan modal awal ${CurrencyFormatter.format(amount)}',
            ),
            backgroundColor: AppTheme.secondary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shiftProvider.errorMessage ?? 'Gagal membuka shift'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final roleLabel = (user?.isAdmin ?? false) ? 'Admin' : 'Kasir';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buka Shift Kasir ($roleLabel)',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Operator: ${user?.name ?? roleLabel} • Masukkan modal awal laci kasir untuk mulai bertransaksi',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Starting Cash Input
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Modal Awal Kasir (Rp)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  hintText: 'e.g. 100.000',
                ),
              ),
              const SizedBox(height: 12),

              // Preset Quick Buttons
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presetAmounts.map((amt) {
                  return ActionChip(
                    label: Text(CurrencyFormatter.format(amt)),
                    labelStyle: const TextStyle(fontSize: 11),
                    onPressed: () {
                      _cashController.text = CurrencyFormatter.formatCompact(amt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
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
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleStartShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Mulai Shift'),
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
}
