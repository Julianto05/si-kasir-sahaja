import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/store_settings_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/transaction_service.dart';

/// Provider managing active POS cart, calculations, checkout, and inventory validation.
class PosProvider extends ChangeNotifier {
  final TransactionService _transactionService = TransactionService();

  final List<TransactionItemModel> _cartItems = [];
  double _discount = 0.0;
  String _paymentMethod = 'Cash';
  double _paidAmount = 0.0;
  String _notes = '';
  bool _isProcessing = false;
  String? _errorMessage;

  // ─── Getters ────────────────────────────────────────────────

  List<TransactionItemModel> get cartItems => List.unmodifiable(_cartItems);
  double get discount => _discount;
  String get paymentMethod => _paymentMethod;
  double get paidAmount => _paidAmount;
  String get notes => _notes;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  bool get isCartEmpty => _cartItems.isEmpty;
  int get totalItemCount =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  /// Returns current quantity of a specific product in the cart.
  int getItemQuantity(String productId) {
    final item = _cartItems.where((i) => i.productId == productId).firstOrNull;
    return item?.quantity ?? 0;
  }

  /// Subtotal before discount, tax, and service charge.
  double get subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Total cost price for margin/profit calculation.
  double get totalCostPrice => _cartItems.fold(
      0.0, (sum, item) => sum + (item.costPrice * item.quantity));

  /// Calculates tax amount based on store settings.
  double calculateTax(StoreSettingsModel settings) {
    if (!settings.enableTax || settings.taxPercentage <= 0) return 0.0;
    final taxableAmount = (subtotal - _discount).clamp(0.0, double.infinity);
    return (taxableAmount * settings.taxPercentage) / 100.0;
  }

  /// Calculates service charge based on store settings.
  double calculateServiceCharge(StoreSettingsModel settings) {
    if (!settings.enableServiceCharge || settings.serviceChargePercentage <= 0) {
      return 0.0;
    }
    final baseAmount = (subtotal - _discount).clamp(0.0, double.infinity);
    return (baseAmount * settings.serviceChargePercentage) / 100.0;
  }

  /// Total amount payable.
  double calculateTotal(StoreSettingsModel settings) {
    final afterDiscount = (subtotal - _discount).clamp(0.0, double.infinity);
    final tax = calculateTax(settings);
    final service = calculateServiceCharge(settings);
    return afterDiscount + tax + service;
  }

  /// Change returned to customer.
  double calculateChange(StoreSettingsModel settings) {
    final total = calculateTotal(settings);
    if (_paidAmount <= total) return 0.0;
    return _paidAmount - total;
  }

  // ─── Cart Operations ────────────────────────────────────────

  /// Adds a product to the active cart.
  /// Validates available stock quantity.
  bool addToCart(ProductModel product) {
    if (product.stock <= 0) {
      _errorMessage = 'Stok produk "${product.name}" telah habis!';
      notifyListeners();
      return false;
    }

    final index =
        _cartItems.indexWhere((item) => item.productId == product.id);

    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      if (currentQty + 1 > product.stock) {
        _errorMessage =
            'Tidak bisa menambah item. Stok tersedia hanya ${product.stock} ${product.unit}.';
        notifyListeners();
        return false;
      }
      final newQty = currentQty + 1;
      _cartItems[index] = _cartItems[index].copyWith(
        quantity: newQty,
        subtotal: _cartItems[index].price * newQty,
      );
    } else {
      _cartItems.add(TransactionItemModel(
        productId: product.id,
        productName: product.name,
        productCode: product.code,
        price: product.sellingPrice,
        costPrice: product.costPrice,
        quantity: 1,
        unit: product.unit,
        subtotal: product.sellingPrice,
      ));
    }

    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Sets absolute quantity for an item.
  bool setItemQuantity(String productId, int newQty, int maxStock) {
    if (newQty <= 0) {
      removeFromCart(productId);
      return true;
    }

    if (newQty > maxStock) {
      _errorMessage = 'Maksimal stok tersedia adalah $maxStock.';
      notifyListeners();
      return false;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _cartItems[index] = _cartItems[index].copyWith(
        quantity: newQty,
        subtotal: _cartItems[index].price * newQty,
      );
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Increments quantity of an item.
  bool incrementItem(String productId, int maxStock) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      if (currentQty + 1 > maxStock) {
        _errorMessage = 'Stok tidak mencukupi (Maksimal: $maxStock).';
        notifyListeners();
        return false;
      }
      return setItemQuantity(productId, currentQty + 1, maxStock);
    }
    return false;
  }

  /// Decrements quantity of an item.
  void decrementItem(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      if (currentQty > 1) {
        final newQty = currentQty - 1;
        _cartItems[index] = _cartItems[index].copyWith(
          quantity: newQty,
          subtotal: _cartItems[index].price * newQty,
        );
      } else {
        _cartItems.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Removes an item from cart.
  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Empties the cart.
  void clearCart() {
    _cartItems.clear();
    _discount = 0.0;
    _paidAmount = 0.0;
    _notes = '';
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Payment & Checkout ─────────────────────────────────────

  void setDiscount(double amount) {
    _discount = amount.clamp(0.0, subtotal);
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setPaidAmount(double amount) {
    _paidAmount = amount;
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  /// Executes checkout and saves transaction into Firestore atomically.
  Future<TransactionModel?> checkout({
    required UserModel cashier,
    required StoreSettingsModel settings,
  }) async {
    if (_cartItems.isEmpty) {
      _errorMessage = 'Keranjang belanja masih kosong!';
      notifyListeners();
      return null;
    }

    final total = calculateTotal(settings);
    if (_paidAmount < total) {
      _errorMessage = 'Nominal pembayaran kurang dari total tagihan!';
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final invoiceNumber = await _transactionService.generateInvoiceNumber(
        settings.invoicePrefix.isNotEmpty ? settings.invoicePrefix : 'TRX',
      );

      final tax = calculateTax(settings);
      final service = calculateServiceCharge(settings);
      final change = calculateChange(settings);
      final now = DateTime.now();

      final transaction = TransactionModel(
        id: '',
        invoiceNumber: invoiceNumber,
        cashierId: cashier.uid,
        cashierName: cashier.name,
        subtotal: subtotal,
        discount: _discount,
        tax: tax,
        serviceCharge: service,
        total: total,
        totalCostPrice: totalCostPrice,
        paymentMethod: _paymentMethod,
        paidAmount: _paidAmount,
        changeAmount: change,
        status: AppConstants.statusCompleted,
        notes: _notes,
        items: List.from(_cartItems),
        createdAt: now,
      );

      final newDocId =
          await _transactionService.executeTransaction(transaction);

      final completedTransaction = transaction.copyWith(id: newDocId);

      // Clear cart on successful transaction
      clearCart();
      _isProcessing = false;
      notifyListeners();

      return completedTransaction;
    } catch (e) {
      _errorMessage = 'Transaksi gagal diproses: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
