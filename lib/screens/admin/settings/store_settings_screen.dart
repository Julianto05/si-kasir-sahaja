import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../widgets/app_background.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';
import 'widgets/reset_data_dialog.dart';

/// Screen for configuring store identity, taxes, payment methods, loyalty points,
/// backup/restore JSON, and operational data reset (PRD Section 5.6).
class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _taxController;
  late final TextEditingController _serviceController;
  late final TextEditingController _footerController;
  late final TextEditingController _prefixController;
  late final TextEditingController _pointsPerAmountController;
  late final TextEditingController _pointRedeemValueController;
  late final TextEditingController _memberDiscountController;

  late bool _enableTax;
  late bool _enableService;
  late bool _enableLoyaltyPoints;
  late bool _enableBarcodeScanner;
  late Set<String> _activePaymentMethods;
  bool _isSaving = false;

  static const List<String> _allPaymentMethods = [
    'Cash',
    'QRIS',
    'Transfer',
    'Debit',
    'Kredit',
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<StoreSettingsProvider>().settings;

    _nameController = TextEditingController(text: settings.storeName);
    _addressController = TextEditingController(text: settings.storeAddress);
    _phoneController = TextEditingController(text: settings.storePhone);
    _emailController = TextEditingController(text: settings.storeEmail);
    _taxController = TextEditingController(
      text: settings.taxPercentage.toString(),
    );
    _serviceController = TextEditingController(
      text: settings.serviceChargePercentage.toString(),
    );
    _footerController = TextEditingController(text: settings.receiptFooter);
    _prefixController = TextEditingController(text: settings.invoicePrefix);
    _pointsPerAmountController = TextEditingController(
      text: settings.pointsPerAmount.toInt().toString(),
    );
    _pointRedeemValueController = TextEditingController(
      text: settings.pointRedeemValue.toInt().toString(),
    );
    _memberDiscountController = TextEditingController(
      text: settings.memberDiscountPercentage.toString(),
    );

    _enableTax = settings.enableTax;
    _enableService = settings.enableServiceCharge;
    _enableLoyaltyPoints = settings.enableLoyaltyPoints;
    _enableBarcodeScanner = settings.enableBarcodeScanner;
    _activePaymentMethods = Set<String>.from(settings.activePaymentMethods);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxController.dispose();
    _serviceController.dispose();
    _footerController.dispose();
    _prefixController.dispose();
    _pointsPerAmountController.dispose();
    _pointRedeemValueController.dispose();
    _memberDiscountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final current = context.read<StoreSettingsProvider>().settings;
    final updated = current.copyWith(
      storeName: _nameController.text.trim(),
      storeAddress: _addressController.text.trim(),
      storePhone: _phoneController.text.trim(),
      storeEmail: _emailController.text.trim(),
      taxPercentage: double.tryParse(_taxController.text) ?? 0.0,
      serviceChargePercentage: double.tryParse(_serviceController.text) ?? 0.0,
      receiptFooter: _footerController.text.trim(),
      invoicePrefix: _prefixController.text.trim(),
      enableTax: _enableTax,
      enableServiceCharge: _enableService,
      activePaymentMethods: _activePaymentMethods.isEmpty
          ? ['Cash']
          : _activePaymentMethods.toList(),
      enableLoyaltyPoints: _enableLoyaltyPoints,
      pointsPerAmount:
          double.tryParse(_pointsPerAmountController.text) ?? 10000.0,
      pointRedeemValue:
          double.tryParse(_pointRedeemValueController.text) ?? 100.0,
      memberDiscountPercentage:
          double.tryParse(_memberDiscountController.text) ?? 0.0,
      enableBarcodeScanner: _enableBarcodeScanner,
    );

    final success = await context.read<StoreSettingsProvider>().updateSettings(
      updated,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan toko berhasil disimpan!'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
  }

  void _showBackupDatabaseDialog(BuildContext context) {
    final settings = context.read<StoreSettingsProvider>().settings;
    final products = context.read<ProductProvider>().allProducts;
    final categories = context.read<CategoryProvider>().allCategories;
    final customers = context.read<CustomerProvider>().allCustomers;
    final suppliers = context.read<SupplierProvider>().allSuppliers;

    final backupPayload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'storeSettings': settings.toMap(),
      'categoriesCount': categories.length,
      'productsCount': products.length,
      'customersCount': customers.length,
      'suppliersCount': suppliers.length,
      'productsCsv': context.read<ProductProvider>().exportProductsToCsv(),
    };
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(backupPayload);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Backup & Export Data Toko (JSON)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ringkasan: ${products.length} Produk, ${categories.length} Kategori, ${customers.length} Pelanggan, ${suppliers.length} Supplier.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonString));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Backup JSON berhasil disalin ke Clipboard!',
                              ),
                              backgroundColor: AppTheme.secondary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Salin Backup'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Simpan Pengaturan',
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'settings'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'settings'),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.containerPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Profil Toko
                      _buildSectionHeader('Identitas Toko'),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Toko *',
                          hintText: 'e.g. Toko Berkah Sejahtera',
                          prefixIcon: Icon(Icons.storefront_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Nama toko wajib'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Lengkap',
                          hintText: 'Jl. Merdeka No. 45, Jakarta',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 460) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'No. Telepon / WhatsApp',
                                    hintText: '0812-3456-7890',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Toko',
                                    hintText: 'store@email.com',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'No. Telepon / WhatsApp',
                                    hintText: '0812-3456-7890',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Toko',
                                    hintText: 'store@email.com',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Metode Pembayaran & Perangkat
                      _buildSectionHeader('Metode Pembayaran & Perangkat'),
                      const SizedBox(height: 8),
                      const Text(
                        'Pilih metode pembayaran yang aktif di layar Kasir / POS:',
                        style: TextStyle(fontSize: 12, color: AppTheme.outline),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _allPaymentMethods.map((m) {
                          final selected = _activePaymentMethods.contains(m);
                          return FilterChip(
                            label: Text(m),
                            selected: selected,
                            selectedColor: AppTheme.secondaryContainer,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _activePaymentMethods.add(m);
                                } else if (_activePaymentMethods.length > 1) {
                                  _activePaymentMethods.remove(m);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SwitchListTile(
                        title: const Text('Aktifkan Pemindai Barcode Kamera'),
                        subtitle: const Text(
                          'Tampilkan tombol scan barcode cepat pada POS & Produk',
                        ),
                        value: _enableBarcodeScanner,
                        activeThumbColor: AppTheme.secondary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _enableBarcodeScanner = val),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Loyalitas Pelanggan & Member (PRD Section 5.8)
                      _buildSectionHeader('Program Loyalitas & Member'),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Aktifkan Poin Loyalitas Member'),
                        subtitle: const Text(
                          'Pelanggan member otomatis mendapat & menukar poin',
                        ),
                        value: _enableLoyaltyPoints,
                        activeThumbColor: AppTheme.secondary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _enableLoyaltyPoints = val),
                      ),
                      if (_enableLoyaltyPoints) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 460) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _pointsPerAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Belanja per 1 Poin (Rp)',
                                      prefixText: 'Rp ',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _pointRedeemValueController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Nilai Tukar 1 Poin (Rp)',
                                      prefixText: 'Rp ',
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _pointsPerAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Belanja per 1 Poin (Rp)',
                                      prefixText: 'Rp ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _pointRedeemValueController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Nilai Tukar 1 Poin (Rp)',
                                      prefixText: 'Rp ',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextFormField(
                        controller: _memberDiscountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Diskon Otomatis Member (%)',
                          suffixText: '%',
                          prefixIcon: Icon(Icons.card_membership_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 4: Pajak & Biaya Layanan
                      _buildSectionHeader('Pajak & Biaya Tambahan'),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Aktifkan Pajak (PPN)'),
                        subtitle: const Text(
                          'Ditambahkan otomatis saat checkout',
                        ),
                        value: _enableTax,
                        activeThumbColor: AppTheme.secondary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _enableTax = val),
                      ),

                      if (_enableTax) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _taxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Persentase Pajak (%)',
                            hintText: '11',
                            suffixText: '%',
                            prefixIcon: Icon(Icons.percent_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SwitchListTile(
                        title: const Text(
                          'Aktifkan Biaya Layanan (Service Charge)',
                        ),
                        subtitle: const Text(
                          'Ditambahkan pada total transaksi',
                        ),
                        value: _enableService,
                        activeThumbColor: AppTheme.secondary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _enableService = val),
                      ),

                      if (_enableService) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _serviceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Persentase Service Charge (%)',
                            hintText: '5',
                            suffixText: '%',
                            prefixIcon: Icon(Icons.room_service_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Section 5: Format Struk
                      _buildSectionHeader('Format Struk & Nota'),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _prefixController,
                        decoration: const InputDecoration(
                          labelText: 'Prefix Nomor Nota',
                          hintText: 'TRX',
                          prefixIcon: Icon(Icons.receipt_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _footerController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Pesan Footer Struk',
                          hintText:
                              'e.g. Barang yang dibeli tidak dapat ditukar',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 6: Backup & Reset Data Operasional
                      _buildSectionHeader('Backup & Pemeliharaan Data'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showBackupDatabaseDialog(context),
                        icon: const Icon(
                          Icons.cloud_download_outlined,
                          size: 18,
                        ),
                        label: const Text('Backup / Export Data Toko (JSON)'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.restore_page_rounded,
                                    color: AppTheme.error,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Reset Data Operasional',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                      Text(
                                        'Hapus riwayat transaksi, shift, atau log stok (1 Hari, Mingguan, Bulanan, Custom)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => ResetDataDialog.show(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  side: const BorderSide(color: AppTheme.error),
                                ),
                                icon: const Icon(
                                  Icons.delete_sweep_rounded,
                                  size: 18,
                                ),
                                label: const Text('Buka Pengaturan Reset Data'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: AppTheme.touchTarget,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Simpan Pengaturan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
