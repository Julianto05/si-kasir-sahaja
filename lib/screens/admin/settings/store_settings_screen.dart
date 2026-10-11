import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/store_settings_provider.dart';
import '../widgets/admin_drawer.dart';

/// Screen for configuring store identity, taxes, and receipt footer message.
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

  late bool _enableTax;
  late bool _enableService;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<StoreSettingsProvider>().settings;

    _nameController = TextEditingController(text: settings.storeName);
    _addressController = TextEditingController(text: settings.storeAddress);
    _phoneController = TextEditingController(text: settings.storePhone);
    _emailController = TextEditingController(text: settings.storeEmail);
    _taxController =
        TextEditingController(text: settings.taxPercentage.toString());
    _serviceController = TextEditingController(
        text: settings.serviceChargePercentage.toString());
    _footerController = TextEditingController(text: settings.receiptFooter);
    _prefixController = TextEditingController(text: settings.invoicePrefix);

    _enableTax = settings.enableTax;
    _enableService = settings.enableServiceCharge;
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
      serviceChargePercentage:
          double.tryParse(_serviceController.text) ?? 0.0,
      receiptFooter: _footerController.text.trim(),
      invoicePrefix: _prefixController.text.trim(),
      enableTax: _enableTax,
      enableServiceCharge: _enableService,
    );

    final success =
        await context.read<StoreSettingsProvider>().updateSettings(updated);

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
      body: SafeArea(
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
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Nama toko wajib' : null,
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

                Row(
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
                ),
                const SizedBox(height: 24),

                // Section 2: Pajak & Biaya Layanan
                _buildSectionHeader('Pajak & Biaya Tambahan'),
                const SizedBox(height: 12),

                SwitchListTile(
                  title: const Text('Aktifkan Pajak (PPN)'),
                  subtitle: const Text('Ditambahkan otomatis saat checkout'),
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
                  title: const Text('Aktifkan Biaya Layanan (Service Charge)'),
                  subtitle: const Text('Ditambahkan pada total transaksi'),
                  value: _enableService,
                  activeThumbColor: AppTheme.secondary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _enableService = val),
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

                // Section 3: Format Struk
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
                    hintText: 'e.g. Barang yang dibeli tidak dapat ditukar',
                    prefixIcon: Icon(Icons.notes_rounded),
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
