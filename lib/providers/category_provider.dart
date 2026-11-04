import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../services/category_service.dart';

/// Provider for managing categories state and real-time synchronization.
class CategoryProvider extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  List<CategoryModel> _categories = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<CategoryModel>>? _subscription;

  CategoryProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  /// All categories fetched from Firestore.
  List<CategoryModel> get allCategories => _categories;

  /// Only active categories for dropdowns and POS catalog.
  List<CategoryModel> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  /// Filtered categories based on search query.
  List<CategoryModel> get filteredCategories {
    if (_searchQuery.trim().isEmpty) return _categories;
    final query = _searchQuery.toLowerCase().trim();
    return _categories.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();
  }

  // ─── Stream Initialization ──────────────────────────────────

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _categoryService.streamCategories().listen(
      (categories) {
        _categories = categories;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data kategori: $error';
        notifyListeners();
      },
    );
  }

  /// Manually refreshes categories from Firestore.
  Future<void> refreshCategories() async {
    try {
      _isLoading = true;
      notifyListeners();
      final categories = await _categoryService.getCategories();
      _categories = categories;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data kategori: $e';
      notifyListeners();
    }
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Updates local search filter.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Adds a new category after validating uniqueness.
  Future<bool> addCategory({
    required String name,
    String description = '',
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exists = await _categoryService.isCategoryNameExists(name);
      if (exists) {
        _errorMessage = 'Kategori dengan nama "$name" sudah ada.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final newCategory = CategoryModel(
        id: '',
        name: name,
        description: description,
        isActive: isActive,
        createdAt: now,
        updatedAt: now,
      );

      await _categoryService.addCategory(newCategory);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan kategori: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing category.
  Future<bool> updateCategory(CategoryModel category) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exists = await _categoryService.isCategoryNameExists(
        category.name,
        excludeId: category.id,
      );
      if (exists) {
        _errorMessage = 'Kategori dengan nama "${category.name}" sudah ada.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _categoryService.updateCategory(category);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui kategori: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggles active status of a category.
  Future<bool> toggleCategoryStatus(CategoryModel category) async {
    try {
      await _categoryService.toggleCategoryStatus(
        category.id,
        category.isActive,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengubah status kategori: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a category.
  Future<bool> deleteCategory(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _categoryService.deleteCategory(id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus kategori: $e';
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
