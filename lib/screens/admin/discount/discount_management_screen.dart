import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/discount_model.dart';
import '../../../providers/discount_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Module 5.11: Diskon & Promo (Product Discount, Transaction Discount, Member Promo, BOGO, Coupons).
class DiscountManagementScreen extends StatelessWidget {
  const DiscountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final discProv = context.watch<DiscountProvider>();
    final discounts = discProv.allDiscounts;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Kelola Diskon & Promo')),
      drawer: const AdminDrawer(currentRoute: 'discounts'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'discounts'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDiscountFormDialog(context),
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Promo / Diskon'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: discounts.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada program diskon atau kupon promo aktif.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: discounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = discounts[index];
                    final dateFmt = DateFormat('dd MMM yyyy');
                    final valStr = d.isPercentage
                        ? '${d.value.toStringAsFixed(0)}%'
                        : CurrencyFormatter.format(d.value);

                    return ScaleTap(
                      onTap: () =>
                          _showDiscountFormDialog(context, discount: d),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(
                            color: d.isValidNow
                                ? AppTheme.secondary.withValues(alpha: 0.4)
                                : AppTheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: d.isValidNow
                                    ? AppTheme.secondaryContainer
                                    : AppTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusDefault,
                                ),
                              ),
                              child: Icon(
                                Icons.local_offer_rounded,
                                color: d.isValidNow
                                    ? AppTheme.onSecondaryContainer
                                    : AppTheme.outline,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          d.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                        ),
                                        child: Text(
                                          d.typeLabel,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Potongan: $valStr • Min. Belanja: ${CurrencyFormatter.format(d.minPurchase)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.secondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Periode: ${dateFmt.format(d.startDate)} - ${dateFmt.format(d.endDate)}${d.code.isNotEmpty ? " • Kode: ${d.code}" : ""}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppTheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: d.isActive,
                              activeThumbColor: AppTheme.secondary,
                              onChanged: (val) {
                                discProv.updateDiscount(
                                  d.copyWith(isActive: val),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showDiscountFormDialog(
    BuildContext context, {
    DiscountModel? discount,
  }) {
    final nameCtrl = TextEditingController(text: discount?.name ?? '');
    final codeCtrl = TextEditingController(text: discount?.code ?? '');
    final valCtrl = TextEditingController(
      text: discount != null ? discount.value.toInt().toString() : '10',
    );
    final minCtrl = TextEditingController(
      text: discount != null ? discount.minPurchase.toInt().toString() : '0',
    );
    String selectedType = discount?.type ?? 'transaksi';
    bool isPct = discount?.isPercentage ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
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
                  Text(
                    discount == null
                        ? 'Buat Diskon / Promo Baru'
                        : 'Edit Diskon / Promo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Program Promo *',
                      hintText: 'e.g. Promo Akhir Pekan / Member Spesial',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipe Promo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'transaksi',
                        child: Text('Diskon Transaksi'),
                      ),
                      DropdownMenuItem(
                        value: 'member',
                        child: Text('Diskon Khusus Member'),
                      ),
                      DropdownMenuItem(
                        value: 'kupon',
                        child: Text('Kupon Voucher'),
                      ),
                      DropdownMenuItem(
                        value: 'bogo',
                        child: Text('Promo Buy 1 Get 1'),
                      ),
                      DropdownMenuItem(
                        value: 'produk',
                        child: Text('Diskon Produk'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kode Kupon (Opsional)',
                      hintText: 'e.g. RINJANI10',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isPct
                                ? 'Persentase (%)'
                                : 'Nominal (Rp)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('%'),
                        selected: isPct,
                        onSelected: (_) => setStateDialog(() => isPct = true),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('Rp'),
                        selected: !isPct,
                        onSelected: (_) => setStateDialog(() => isPct = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimal Belanja (Rp)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (discount != null) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.error,
                          ),
                          onPressed: () async {
                            await context
                                .read<DiscountProvider>()
                                .deleteDiscount(discount.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final val = double.tryParse(valCtrl.text) ?? 0.0;
                            final minP = double.tryParse(minCtrl.text) ?? 0.0;
                            final prov = context.read<DiscountProvider>();

                            final model = DiscountModel(
                              id: discount?.id ?? '',
                              name: nameCtrl.text,
                              code: codeCtrl.text,
                              type: selectedType,
                              value: val,
                              isPercentage: isPct,
                              minPurchase: minP,
                              startDate: discount?.startDate ?? DateTime.now(),
                              endDate:
                                  discount?.endDate ??
                                  DateTime.now().add(const Duration(days: 60)),
                              isActive: discount?.isActive ?? true,
                              createdAt: discount?.createdAt ?? DateTime.now(),
                            );

                            if (discount == null) {
                              await prov.addDiscount(model);
                            } else {
                              await prov.updateDiscount(model);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
