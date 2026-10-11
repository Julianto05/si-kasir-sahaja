import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/storage_service.dart';

/// Provider for managing products state, search filtering, and image upload orchestration.
class ProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();
  final StorageService _storageService = StorageService();

  List<ProductModel> _products = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  bool _showOnlyLowStock = false;
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

  /// All products fetched from Firestore.
  List<ProductModel> get allProducts => _products;

  /// Only active products (used for POS).
  List<ProductModel> get activeProducts =>
      _products.where((p) => p.isActive).toList();

  /// Products whose current stock is at or below minimumStock.
  List<ProductModel> get lowStockProducts =>
      _products.where((p) => p.isLowStock && p.isActive).toList();

  /// Total count of products with low stock.
  int get lowStockCount => lowStockProducts.length;

  /// Filtered products for UI lists based on category, search query, and low stock toggle.
  List<ProductModel> get filteredProducts {
    return _products.where((product) {
      // Category filter
      if (_selectedCategoryId != 'all' &&
          product.categoryId != _selectedCategoryId) {
        return false;
      }

      // Low stock toggle
      if (_showOnlyLowStock && !product.isLowStock) {
        return false;
      }

      // Search query (name, code, barcode)
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final nameMatch = product.name.toLowerCase().contains(query);
        final codeMatch = product.code.toLowerCase().contains(query);
        final barcodeMatch = product.barcode.toLowerCase().contains(query);
        if (!nameMatch && !codeMatch && !barcodeMatch) {
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

  void resetFilters() {
    _selectedCategoryId = 'all';
    _searchQuery = '';
    _showOnlyLowStock = false;
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
      // Check memory cache first
      final cached = _products.where((p) => p.barcode == clean).firstOrNull;
      if (cached != null) return cached;

      // Check Firestore
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
    required String categoryId,
    required String categoryName,
    required double costPrice,
    required double sellingPrice,
    required int stock,
    int minimumStock = 5,
    String unit = 'pcs',
    XFile? imageFile,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validate code uniqueness
      final codeExists = await _productService.isCodeExists(code);
      if (codeExists) {
        _errorMessage = 'Kode produk "$code" sudah digunakan.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate barcode uniqueness if provided
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

      // Temporary product model
      final productDraft = ProductModel(
        id: '',
        code: code.trim().toUpperCase(),
        barcode: barcode.trim(),
        name: name.trim(),
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

      // Save initial product to get generated doc ID
      final newDocId = await _productService.addProduct(productDraft);

      // Upload image if selected
      if (imageFile != null) {
        try {
          imageUrl = await _storageService.uploadProductImage(imageFile, newDocId);
          // Update product with image URL
          final updatedProduct = productDraft.copyWith(
            id: newDocId,
            imageUrl: imageUrl,
          );
          await _productService.updateProduct(updatedProduct);
        } catch (storageError) {
          // If storage fails, product is still saved
          _errorMessage = 'Produk tersimpan, namun gagal mengunggah foto: $storageError';
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Validate code uniqueness
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

      // Validate barcode uniqueness if changed
      if (product.barcode.trim().isNotEmpty) {
        final barcodeExists = await _productService.isBarcodeExists(
          product.barcode,
          excludeId: product.id,
        );
        if (barcodeExists) {
          _errorMessage = 'Barcode "${product.barcode}" sudah digunakan produk lain.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      String? imageUrl = product.imageUrl;

      // Upload new image if provided
      if (newImageFile != null) {
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

  /// Deletes a product and its associated photo if present.
  Future<bool> deleteProduct(ProductModel product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Delete image from storage if exists
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
