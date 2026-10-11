import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../models/stock_movement_model.dart';
import '../models/user_model.dart';
import '../services/stock_service.dart';

/// Provider for managing inventory movements, restock operations, and manual adjustments.
class StockProvider extends ChangeNotifier {
  final StockService _stockService = StockService();

  List<StockMovementModel> _movements = [];
  String _selectedType = 'all';
  String _selectedProductId = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<StockMovementModel>>? _subscription;

  StockProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedType => _selectedType;
  String get selectedProductId => _selectedProductId;
  String get searchQuery => _searchQuery;

  List<StockMovementModel> get allMovements => _movements;

  /// Filtered inventory movements.
  List<StockMovementModel> get filteredMovements {
    return _movements.where((m) {
      if (_selectedType != 'all' && m.type != _selectedType) {
        return false;
      }
      if (_selectedProductId != 'all' && m.productId != _selectedProductId) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchProduct = m.productName.toLowerCase().contains(q);
        final matchCode = m.productCode.toLowerCase().contains(q);
        final matchNotes = m.notes.toLowerCase().contains(q);
        final matchUser = m.userName.toLowerCase().contains(q);
        if (!matchProduct && !matchCode && !matchNotes && !matchUser) {
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

    _subscription = _stockService.streamMovements().listen(
      (movements) {
        _movements = movements;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat mutasi stok: $error';
        notifyListeners();
      },
    );
  }

  // ─── Filters ────────────────────────────────────────────────

  void setTypeFilter(String type) {
    _selectedType = type;
    notifyListeners();
  }

  void setProductFilter(String productId) {
    _selectedProductId = productId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void resetFilters() {
    _selectedType = 'all';
    _selectedProductId = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Adds stock from supplier.
  Future<bool> restockProduct({
    required ProductModel product,
    required int addQuantity,
    required String notes,
    required UserModel user,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _stockService.addStockIn(
        productId: product.id,
        productName: product.name,
        productCode: product.code,
        currentStock: product.stock,
        addQuantity: addQuantity,
        notes: notes,
        userId: user.uid,
        userName: user.name,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambah stok: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Adjusts stock count manually.
  Future<bool> adjustStock({
    required ProductModel product,
    required int newStock,
    required String reason,
    required UserModel user,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _stockService.adjustStock(
        productId: product.id,
        productName: product.name,
        productCode: product.code,
        currentStock: product.stock,
        newStock: newStock,
        reason: reason,
        userId: user.uid,
        userName: user.name,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyesuaikan stok: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

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
