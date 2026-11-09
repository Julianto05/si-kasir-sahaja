import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/image_cropper_util.dart';
import '../../../models/product_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/barcode_scanner_modal.dart';
import '../../../widgets/product_image.dart';

/// Screen for adding or editing a product in SiKasirSahaja POS (PRD Section 5.4).
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  static Future<bool?> navigate(BuildContext context, {ProductModel? product}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _variantsController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minStockController;
  late final TextEditingController _unitController;

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  DateTime? _expiryDate;
  bool _isActive = true;

  XFile? _selectedImageFile;
  Uint8List? _croppedImageBytes;
  bool _isSubmitting = false;

  bool get _isEdit => widget.product != null;

  static const List<String> _commonUnits = [
    'pcs',
    'pack',
    'botol',
    'kg',
    'gram',
    'liter',
    'dus',
    'porsi',
    'box',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _codeController = TextEditingController(text: p?.code ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _variantsController = TextEditingController(
      text: p != null && p.variants.isNotEmpty ? p.variants.join(', ') : '',
    );
    _costPriceController = TextEditingController(
      text: p != null ? p.costPrice.toInt().toString() : '',
    );
    _sellingPriceController = TextEditingController(
      text: p != null ? p.sellingPrice.toInt().toString() : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stock.toString() : '0',
    );
    _minStockController = TextEditingController(
      text: p != null ? p.minimumStock.toString() : '5',
    );
    _unitController = TextEditingController(text: p?.unit ?? 'pcs');

    _selectedCategoryId = p?.categoryId;
    _selectedCategoryName = p?.categoryName;
    _expiryDate = p?.expiryDate;
    _isActive = p?.isActive ?? true;

    if (!_isEdit && _codeController.text.isEmpty) {
      _autoGenerateCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _variantsController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _autoGenerateCode() async {
    final code = await context.read<ProductProvider>().suggestNextCode();
    if (mounted && _codeController.text.isEmpty) {
      setState(() {
        _codeController.text = code;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final scannedResult = await BarcodeScannerModal.show(context);
    if (scannedResult != null && scannedResult.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedResult;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        final rawBytes = await picked.readAsBytes();
        final squareBytes = await ImageCropperUtil.cropToSquare(rawBytes);

        setState(() {
          _selectedImageFile = picked;
          _croppedImageBytes = squareBytes;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil disesuaikan ke rasio 1:1 (Kotak)'),
              backgroundColor: AppTheme.secondary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses gambar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori produk'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<ProductProvider>();
    final costPrice =
        double.tryParse(_costPriceController.text.replaceAll('.', '')) ?? 0;
    final sellingPrice =
        double.tryParse(_sellingPriceController.text.replaceAll('.', '')) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;
    final minStock = int.tryParse(_minStockController.text) ?? 5;
    final variantsList = _variantsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    bool success;

    if (_isEdit) {
      final updated = widget.product!.copyWith(
        code: _codeController.text.trim(),
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        variants: variantsList,
        expiryDate: _expiryDate,
        clearExpiryDate: _expiryDate == null,
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName ?? '',
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stock: stock,
        minimumStock: minStock,
        unit: _unitController.text.trim(),
        isActive: _isActive,
      );
      success = await provider.updateProduct(
        product: updated,
        newImageFile: _selectedImageFile,
        newImageBytes: _croppedImageBytes,
      );
    } else {
      success = await provider.addProduct(
        code: _codeController.text.trim(),
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        variants: variantsList,
        expiryDate: _expiryDate,
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName ?? '',
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stock: stock,
        minimumStock: minStock,
        unit: _unitController.text.trim(),
        imageFile: _selectedImageFile,
        imageBytes: _croppedImageBytes,
        isActive: _isActive,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Produk "${_nameController.text}" berhasil diperbarui'
                : 'Produk "${_nameController.text}" berhasil ditambahkan',
          ),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Produk' : 'Tambah Produk Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _isSubmitting ? null : _handleSubmit,
          ),
        ],
      ),
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
                    // Product Photo Picker
                    _buildPhotoPicker(),
                    const SizedBox(height: AppTheme.spacingLg),

                    // Section 1: Data Utama Produk
                    _buildSectionHeader('Informasi Produk'),
                    const SizedBox(height: 12),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nama Produk *',
                        hintText: 'e.g. Air Mineral 600ml',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama produk wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Category Dropdown
                    Consumer<CategoryProvider>(
                      builder: (context, catProvider, _) {
                        final activeCategories = catProvider.activeCategories;
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          hint: const Text('Pilih Kategori'),
                          items: activeCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(cat.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCategoryId = val;
                                final found = activeCategories.firstWhere(
                                  (c) => c.id == val,
                                );
                                _selectedCategoryName = found.name;
                              });
                            }
                          },
                          validator: (val) => val == null
                              ? 'Pilih kategori terlebih dahulu'
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Product Code & Barcode Row
                    Row(
                      children: [
                        // Code
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Kode / SKU *',
                              hintText: 'PRD-0001',
                              prefixIcon: const Icon(Icons.qr_code_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.autorenew_rounded),
                                tooltip: 'Generate Kode Auto',
                                onPressed: _autoGenerateCode,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kode wajib diisi';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Barcode
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Barcode',
                              hintText: '899123...',
                              prefixIcon: const Icon(Icons.barcode_reader),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.center_focus_strong_rounded,
                                ),
                                tooltip: 'Scan Barcode',
                                onPressed: _scanBarcode,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Brand & Variants Row (PRD Section 5.4)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _brandController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Merek / Brand',
                              hintText: 'e.g. Aqua, Indomie',
                              prefixIcon: Icon(
                                Icons.branding_watermark_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _variantsController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Varian (pisahkan koma)',
                              hintText: 'e.g. Dingin, Biasa',
                              prefixIcon: Icon(Icons.style_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Expiry Date Picker
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      tileColor: AppTheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        side: BorderSide(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      leading: const Icon(
                        Icons.event_busy_rounded,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        _expiryDate == null
                            ? 'Tanggal Kedaluwarsa (Opsional)'
                            : 'Kedaluwarsa: ${_expiryDate!.day.toString().padLeft(2, "0")}/${_expiryDate!.month.toString().padLeft(2, "0")}/${_expiryDate!.year}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: _expiryDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () =>
                                  setState(() => _expiryDate = null),
                            )
                          : const Icon(Icons.calendar_month_rounded, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _expiryDate ??
                              DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _expiryDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingLg),

                    // Section 2: Harga & Margin
                    _buildSectionHeader('Harga & Profit'),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Cost Price
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Harga Modal (Rp) *',
                              hintText: 'e.g. 3500',
                              prefixText: 'Rp ',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Harga modal wajib';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Selling Price
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Harga Jual (Rp) *',
                              hintText: 'e.g. 5000',
                              prefixText: 'Rp ',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Harga jual wajib';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),

                    // Profit Calculator Preview
                    _buildProfitMarginPreview(),
                    const SizedBox(height: AppTheme.spacingLg),

                    // Section 3: Stok & Satuan
                    _buildSectionHeader('Inventaris & Stok'),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Stock
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Stok Saat Ini *',
                              hintText: '100',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Stok wajib diisi';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Minimum Stock Warning
                        Expanded(
                          child: TextFormField(
                            controller: _minStockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Stok Minimum *',
                              hintText: '5',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Stok min wajib';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Unit Input & Quick Chips
                    TextFormField(
                      controller: _unitController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Satuan Produk *',
                        hintText: 'pcs, kg, botol, pack',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Satuan wajib'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      children: _commonUnits.map((u) {
                        final isSelected =
                            _unitController.text.toLowerCase().trim() == u;
                        return ChoiceChip(
                          label: Text(u),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _unitController.text = u;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Status Switch
                    SwitchListTile(
                      title: const Text('Status Produk Aktif'),
                      subtitle: Text(
                        _isActive
                            ? 'Produk muncul pada katalog kasir (POS)'
                            : 'Produk disembunyikan dari transaksi kasir',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      value: _isActive,
                      activeThumbColor: AppTheme.secondary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                    const SizedBox(height: AppTheme.spacingXl),

                    // Submit Button
                    SizedBox(
                      height: AppTheme.touchTarget,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                        ),
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

  Widget _buildPhotoPicker() {
    final existingUrl = widget.product?.imageUrl;
    final hasImage =
        _croppedImageBytes != null ||
        _selectedImageFile != null ||
        (existingUrl != null && existingUrl.isNotEmpty);

    return Center(
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: hasImage ? AppTheme.secondary : AppTheme.outlineVariant,
                width: hasImage ? 1.5 : 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_croppedImageBytes != null)
                      Image.memory(_croppedImageBytes!, fit: BoxFit.cover)
                    else if (_selectedImageFile != null)
                      kIsWeb
                          ? Image.network(
                              _selectedImageFile!.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImageFile!.path),
                              fit: BoxFit.cover,
                            )
                    else if (existingUrl != null && existingUrl.isNotEmpty)
                      ProductImage(
                        imageUrl: existingUrl,
                        productName: _nameController.text.isNotEmpty
                            ? _nameController.text
                            : 'Produk',
                        width: 140,
                        height: 140,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      )
                    else
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: AppTheme.outline,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Format Apapun\nUkuran 1:1',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasImage)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: const Text(
                            '1:1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              if (_croppedImageBytes != null || _selectedImageFile != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Hapus Foto Terpilih',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedImageFile = null;
                      _croppedImageBytes = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ],
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

  Widget _buildProfitMarginPreview() {
    final cost =
        double.tryParse(_costPriceController.text.replaceAll('.', '')) ?? 0;
    final selling =
        double.tryParse(_sellingPriceController.text.replaceAll('.', '')) ?? 0;

    if (cost <= 0 || selling <= 0) return const SizedBox.shrink();

    final profit = selling - cost;
    final marginPercent = (profit / selling) * 100;
    final isLoss = profit < 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLoss
            ? AppTheme.errorContainer
            : AppTheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isLoss
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                size: 18,
                color: isLoss ? AppTheme.error : AppTheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                isLoss ? 'Kerugian per unit:' : 'Estimasi Keuntungan:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLoss
                      ? AppTheme.error
                      : AppTheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          Text(
            '${CurrencyFormatter.format(profit)} (${marginPercent.toStringAsFixed(1)}%)',
            style: AppTheme.numericStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isLoss ? AppTheme.error : AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
