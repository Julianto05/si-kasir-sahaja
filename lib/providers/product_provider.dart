import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';
import 'attendance_provider.dart';

/// Provider for managing products state, search filtering, expiry/stock alerts,
/// soft-delete archiving, CSV import/export, and image upload orchestration (PRD Section 5.4).
class ProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();
  final StorageService _storageService = StorageService();

  List<ProductModel> _products = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  bool _showOnlyLowStock = false;
  bool _showArchived = false;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<ProductModel>>? _subscription;

  ProductProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get showOnlyLowStock => _showOnlyLowStock;
  bool get showArchived => _showArchived;

  /// All non-archived products fetched from Firestore.
  List<ProductModel> get allProducts =>
      _products.where((p) => !p.isArchived).toList();

  /// Alias for allProducts.
  List<ProductModel> get products => allProducts;

  /// Archived products (soft deleted).
  List<ProductModel> get archivedProducts =>
      _products.where((p) => p.isArchived).toList();

  /// Only active and non-archived products (used for POS).
  List<ProductModel> get activeProducts =>
      _products.where((p) => p.isActive && !p.isArchived).toList();

  /// Products whose current stock is at or below minimumStock.
  List<ProductModel> get lowStockProducts => _products
      .where((p) => p.isLowStock && p.isActive && !p.isArchived)
      .toList();

  /// Products that are completely out of stock (stok = 0).
  List<ProductModel> get outOfStockProducts => _products
      .where((p) => p.isOutOfStock && p.isActive && !p.isArchived)
      .toList();

  /// Products that are expired or expiring within 30 days.
  List<ProductModel> get expiringOrExpiredProducts => _products
      .where(
        (p) => !p.isArchived && p.isActive && (p.isExpired || p.isNearExpiry),
      )
      .toList();

  /// Total count of products with low stock.
  int get lowStockCount => lowStockProducts.length;

  /// Total inventory valuation (HPP * stock).
  double get totalInventoryCostValue => allProducts.fold(
    0.0,
    (sum, p) => sum + (p.costPrice * (p.stock > 0 ? p.stock : 0)),
  );

  /// Filtered products for UI lists based on category, search query, archive, and low stock toggle.
  List<ProductModel> get filteredProducts {
    return _products.where((product) {
      if (_showArchived != product.isArchived) {
        return false;
      }

      if (_selectedCategoryId != 'all' &&
          product.categoryId != _selectedCategoryId) {
        return false;
      }

      if (_showOnlyLowStock && !product.isLowStock) {
        return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final nameMatch = product.name.toLowerCase().contains(query);
        final codeMatch = product.code.toLowerCase().contains(query);
        final barcodeMatch = product.barcode.toLowerCase().contains(query);
        final brandMatch = product.brand.toLowerCase().contains(query);
        if (!nameMatch && !codeMatch && !barcodeMatch && !brandMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ─── Stream Initialization ──────────────────────────────────

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _productService.streamProducts().listen(
      (products) {
        _products = products;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data produk: $error';
        notifyListeners();
      },
    );
  }

  /// Manually refreshes products from Firestore.
  Future<void> refreshProducts() async {
    try {
      _isLoading = true;
      notifyListeners();
      final products = await _productService.getProducts();
      _products = products;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data produk: $e';
      notifyListeners();
    }
  }

  // ─── Filters & Search ───────────────────────────────────────

  void setCategoryFilter(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleLowStockFilter() {
    _showOnlyLowStock = !_showOnlyLowStock;
    notifyListeners();
  }

  void toggleArchivedFilter([bool? val]) {
    _showArchived = val ?? !_showArchived;
    notifyListeners();
  }

  void toggleShowArchived() => toggleArchivedFilter();

  void resetFilters() {
    _selectedCategoryId = 'all';
    _searchQuery = '';
    _showOnlyLowStock = false;
    _showArchived = false;
    notifyListeners();
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Suggests a sequential code like PRD-0001.
  Future<String> suggestNextCode() async {
    return await _productService.generateNextProductCode();
  }

  /// Finds an active product by barcode directly (for POS scanning).
  Future<ProductModel?> findByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    try {
      final cached = _products
          .where((p) => !p.isArchived && p.barcode == clean)
          .firstOrNull;
      if (cached != null) return cached;

      return await _productService.getProductByBarcode(clean);
    } catch (_) {
      return null;
    }
  }

  /// Adds a new product, optionally uploading a photo to Firebase Storage.
  Future<bool> addProduct({
    required String code,
    required String barcode,
    required String name,
    String brand = '',
    List<String> variants = const [],
    DateTime? expiryDate,
    required String categoryId,
    required String categoryName,
    required double costPrice,
    required double sellingPrice,
    required int stock,
    int minimumStock = 5,
    String unit = 'pcs',
    XFile? imageFile,
    Uint8List? imageBytes,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final codeExists = await _productService.isCodeExists(code);
      if (codeExists) {
        _errorMessage = 'Kode produk "$code" sudah digunakan.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (barcode.trim().isNotEmpty) {
        final barcodeExists = await _productService.isBarcodeExists(barcode);
        if (barcodeExists) {
          _errorMessage = 'Barcode "$barcode" sudah digunakan produk lain.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final now = DateTime.now();
      String? imageUrl;

      final productDraft = ProductModel(
        id: '',
        code: code.trim().toUpperCase(),
        barcode: barcode.trim(),
        name: name.trim(),
        brand: brand.trim(),
        variants: variants,
        expiryDate: expiryDate,
        isArchived: false,
        categoryId: categoryId,
        categoryName: categoryName.trim(),
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stock: stock,
        minimumStock: minimumStock,
        unit: unit.trim(),
        imageUrl: null,
        isActive: isActive,
        createdAt: now,
        updatedAt: now,
      );

      final newDocId = await _productService.addProduct(productDraft);

      if (imageBytes != null) {
        try {
          imageUrl = await _storageService.uploadProductImageBytes(
            imageBytes,
            newDocId,
          );
          final updatedProduct = productDraft.copyWith(
            id: newDocId,
            imageUrl: imageUrl,
          );
          await _productService.updateProduct(updatedProduct);
        } catch (storageError) {
          _errorMessage =
              'Produk tersimpan, namun gagal mengunggah foto: $storageError';
        }
      } else if (imageFile != null) {
        try {
          imageUrl = await _storageService.uploadProductImage(
            imageFile,
            newDocId,
          );
          final updatedProduct = productDraft.copyWith(
            id: newDocId,
            imageUrl: imageUrl,
          );
          await _productService.updateProduct(updatedProduct);
        } catch (storageError) {
          _errorMessage =
              'Produk tersimpan, namun gagal mengunggah foto: $storageError';
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan produk: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing product.
  Future<bool> updateProduct({
    required ProductModel product,
    XFile? newImageFile,
    Uint8List? newImageBytes,
    String? auditUserId,
    String? auditUserName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final codeExists = await _productService.isCodeExists(
        product.code,
        excludeId: product.id,
      );
      if (codeExists) {
        _errorMessage = 'Kode produk "${product.code}" sudah digunakan.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (product.barcode.trim().isNotEmpty) {
        final barcodeExists = await _productService.isBarcodeExists(
          product.barcode,
          excludeId: product.id,
        );
        if (barcodeExists) {
          _errorMessage =
              'Barcode "${product.barcode}" sudah digunakan produk lain.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      String? imageUrl = product.imageUrl;

      if (newImageBytes != null) {
        try {
          imageUrl = await _storageService.uploadProductImageBytes(
            newImageBytes,
            product.id,
          );
        } catch (storageError) {
          _errorMessage = 'Gagal mengunggah foto baru: $storageError';
        }
      } else if (newImageFile != null) {
        try {
          imageUrl = await _storageService.uploadProductImage(
            newImageFile,
            product.id,
          );
        } catch (storageError) {
          _errorMessage = 'Gagal mengunggah foto baru: $storageError';
        }
      }

      final updatedProduct = product.copyWith(
        code: product.code.trim().toUpperCase(),
        imageUrl: imageUrl,
        updatedAt: DateTime.now(),
      );

      await _productService.updateProduct(updatedProduct);

      if (auditUserId != null && auditUserName != null) {
        await AttendanceProvider.logActivity(
          userId: auditUserId,
          userName: auditUserName,
          action:
              'Memperbarui Produk ${product.name} (Jual: Rp ${product.sellingPrice.toInt()})',
          entity: 'products',
          entityId: product.id,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui produk: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggles active status of a product.
  Future<bool> toggleProductStatus(ProductModel product) async {
    try {
      await _productService.toggleProductStatus(product.id, product.isActive);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengubah status produk: $e';
      notifyListeners();
      return false;
    }
  }

  /// Soft-deletes (Archives) or restores a product so report history remains intact (PRD Section 5.4).
  Future<bool> toggleArchiveProduct(ProductModel product) async {
    try {
      final updated = product.copyWith(
        isArchived: !product.isArchived,
        isActive: product.isArchived ? true : false,
        updatedAt: DateTime.now(),
      );
      await _productService.updateProduct(updated);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengarsipkan produk: $e';
      notifyListeners();
      return false;
    }
  }

  /// Permanently deletes a product and its associated photo if present.
  Future<bool> deleteProduct(ProductModel product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
        await _storageService.deleteImageByUrl(product.imageUrl!);
      }

      await _productService.deleteProduct(product.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus produk: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Exports active products into Excel-compatible CSV format (PRD Section 5.4).
  String exportProductsToCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Kode;Barcode;Nama Produk;Merek;Kategori;Harga Modal;Harga Jual;Stok;Min Stok;Satuan;Varian;Kedaluwarsa',
    );
    final dateFmt = DateFormat('yyyy-MM-dd');
    for (final p in allProducts) {
      final expStr = p.expiryDate != null ? dateFmt.format(p.expiryDate!) : '';
      final varStr = p.variants.join(',');
      buffer.writeln(
        '${p.code};${p.barcode};${p.name};${p.brand};${p.categoryName};${p.costPrice.toInt()};${p.sellingPrice.toInt()};${p.stock};${p.minimumStock};${p.unit};$varStr;$expStr',
      );
    }
    return buffer.toString();
  }

  /// Imports products from CSV text lines (PRD Section 5.4).
  Future<int> importProductsFromCsv(
    String csvText, {
    required String defaultCategoryId,
    required String defaultCategoryName,
  }) async {
    int importedCount = 0;
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0 && line.toLowerCase().contains('nama produk')) continue;

      final parts = line.contains(';') ? line.split(';') : line.split(',');
      if (parts.length < 7) continue;

      final code = parts[0].trim().isNotEmpty
          ? parts[0].trim()
          : 'PRD-${DateTime.now().millisecondsSinceEpoch % 100000 + i}';
      final barcode = parts[1].trim();
      final name = parts[2].trim();
      if (name.isEmpty) continue;

      final brand = parts[3].trim();
      final catName = parts[4].trim().isNotEmpty
          ? parts[4].trim()
          : defaultCategoryName;
      final costPrice = double.tryParse(parts[5].trim()) ?? 0.0;
      final sellingPrice = double.tryParse(parts[6].trim()) ?? 0.0;
      final stock = parts.length > 7 ? (int.tryParse(parts[7].trim()) ?? 0) : 0;
      final minStock = parts.length > 8
          ? (int.tryParse(parts[8].trim()) ?? 5)
          : 5;
      final unit = parts.length > 9 && parts[9].trim().isNotEmpty
          ? parts[9].trim()
          : 'pcs';

      final added = await addProduct(
        code: code,
        barcode: barcode,
        name: name,
        brand: brand,
        categoryId: defaultCategoryId,
        categoryName: catName,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stock: stock,
        minimumStock: minStock,
        unit: unit,
      );
      if (added) importedCount++;
    }
    return importedCount;
  }

  /// Clears error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
