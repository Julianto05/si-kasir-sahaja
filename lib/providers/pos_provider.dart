import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/customer_model.dart';
import '../models/discount_model.dart';
import '../models/product_model.dart';
import '../models/store_settings_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/transaction_service.dart';

/// Represents a temporarily parked / held order (PRD Section 5.2).
class HeldOrder {
  final String id;
  final String label;
  final List<TransactionItemModel> items;
  final CustomerModel? customer;
  final double manualDiscount;
  final String notes;
  final DateTime createdAt;

  const HeldOrder({
    required this.id,
    required this.label,
    required this.items,
    this.customer,
    this.manualDiscount = 0.0,
    this.notes = '',
    required this.createdAt,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}

/// Provider managing active POS cart, customer & loyalty points, discounts,
/// held orders, split payments, and checkout execution (PRD Section 5.2).
class PosProvider extends ChangeNotifier {
  final TransactionService _transactionService = TransactionService();

  final List<TransactionItemModel> _cartItems = [];
  final List<HeldOrder> _heldOrders = [];

  CustomerModel? _selectedCustomer;
  DiscountModel? _selectedPromo;
  int _pointsToRedeem = 0;

  double _discount = 0.0;
  String _paymentMethod = 'Cash';
  List<PaymentSplitItem> _splitPayments = [];
  double _paidAmount = 0.0;
  String _notes = '';
  bool _isProcessing = false;
  String? _errorMessage;

  // ─── Getters ────────────────────────────────────────────────

  List<TransactionItemModel> get cartItems => List.unmodifiable(_cartItems);
  List<HeldOrder> get heldOrders => List.unmodifiable(_heldOrders);
  int get heldOrdersCount => _heldOrders.length;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  DiscountModel? get selectedPromo => _selectedPromo;
  DiscountModel? get appliedPromo => _selectedPromo;
  int get pointsToRedeem => _pointsToRedeem;
  int get redeemedPoints => _pointsToRedeem;

  double get discount => _discount;
  String get paymentMethod => _paymentMethod;
  List<PaymentSplitItem> get splitPayments => List.unmodifiable(_splitPayments);
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

  /// Subtotal after per-item discounts, before transaction-level discount, tax, and service charge.
  double get subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Total of per-item discounts.
  double get totalItemDiscounts =>
      _cartItems.fold(0.0, (sum, item) => sum + item.itemDiscount);

  /// Total cost price for margin/profit calculation.
  double get totalCostPrice => _cartItems.fold(
      0.0, (sum, item) => sum + (item.costPrice * item.quantity));

  /// Calculates automatic member discount + promo discount + redeemed points + manual discount.
  double calculateEffectiveDiscount(StoreSettingsModel settings) {
    double totalDisc = _discount;

    // 1. Promo campaign discount
    if (_selectedPromo != null) {
      totalDisc += _selectedPromo!.calculateDiscount(
        subtotal,
        isCustomerMember: _selectedCustomer?.isMember ?? false,
      );
    }

    // 2. Member automatic percentage discount from StoreSettings
    if (_selectedCustomer != null &&
        _selectedCustomer!.isMember &&
        settings.memberDiscountPercentage > 0) {
      totalDisc += (subtotal * settings.memberDiscountPercentage) / 100.0;
    }

    // 3. Loyalty points redemption value
    if (_selectedCustomer != null &&
        _pointsToRedeem > 0 &&
        settings.enableLoyaltyPoints) {
      totalDisc += _pointsToRedeem * settings.pointRedeemValue;
    }

    return totalDisc.clamp(0.0, subtotal);
  }

  /// Alias for calculateEffectiveDiscount + totalItemDiscounts.
  double calculateTotalDiscount(StoreSettingsModel settings) {
    return calculateEffectiveDiscount(settings) + totalItemDiscounts;
  }

  /// Calculates tax amount based on store settings.
  double calculateTax(StoreSettingsModel settings) {
    if (!settings.enableTax || settings.taxPercentage <= 0) return 0.0;
    final effDisc = calculateEffectiveDiscount(settings);
    final taxableAmount = (subtotal - effDisc).clamp(0.0, double.infinity);
    return (taxableAmount * settings.taxPercentage) / 100.0;
  }

  /// Calculates service charge based on store settings.
  double calculateServiceCharge(StoreSettingsModel settings) {
    if (!settings.enableServiceCharge ||
        settings.serviceChargePercentage <= 0) {
      return 0.0;
    }
    final effDisc = calculateEffectiveDiscount(settings);
    final baseAmount = (subtotal - effDisc).clamp(0.0, double.infinity);
    return (baseAmount * settings.serviceChargePercentage) / 100.0;
  }

  /// Total amount payable.
  double calculateTotal(StoreSettingsModel settings) {
    final effDisc = calculateEffectiveDiscount(settings);
    final afterDiscount = (subtotal - effDisc).clamp(0.0, double.infinity);
    final tax = calculateTax(settings);
    final service = calculateServiceCharge(settings);
    return afterDiscount + tax + service;
  }

  /// Loyalty points earned from this transaction.
  int calculatePointsEarned(StoreSettingsModel settings) {
    if (_selectedCustomer == null || !settings.enableLoyaltyPoints) return 0;
    if (settings.pointsPerAmount <= 0) return 0;
    final total = calculateTotal(settings);
    return (total / settings.pointsPerAmount).floor();
  }

  /// Change returned to customer.
  double calculateChange(StoreSettingsModel settings) {
    final total = calculateTotal(settings);
    if (_paidAmount <= total) return 0.0;
    return _paidAmount - total;
  }

  // ─── Customer, Promo & Hold Operations ──────────────────────

  void selectCustomer(CustomerModel? customer) {
    _selectedCustomer = customer;
    _pointsToRedeem = 0;
    notifyListeners();
  }

  void selectPromo(DiscountModel? promo) {
    _selectedPromo = promo;
    notifyListeners();
  }

  void applyPromo(DiscountModel? promo) => selectPromo(promo);

  void setPointsToRedeem(int points) {
    if (_selectedCustomer == null) {
      _pointsToRedeem = 0;
    } else {
      _pointsToRedeem = points.clamp(0, _selectedCustomer!.points);
    }
    notifyListeners();
  }

  void setRedeemedPoints(int points) => setPointsToRedeem(points);

  /// Parks / holds the current cart so the cashier can serve another customer (PRD Section 5.2).
  bool holdCurrentOrder({
    String? customLabel,
    UserModel? cashier,
    StoreSettingsModel? settings,
  }) {
    if (_cartItems.isEmpty) return false;
    final now = DateTime.now();
    final label = (customLabel != null && customLabel.trim().isNotEmpty)
        ? customLabel.trim()
        : (_selectedCustomer?.name ??
            'Antrean #${_heldOrders.length + 1} (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})');

    _heldOrders.add(
      HeldOrder(
        id: now.millisecondsSinceEpoch.toString(),
        label: label,
        items: List<TransactionItemModel>.from(_cartItems),
        customer: _selectedCustomer,
        manualDiscount: _discount,
        notes: _notes,
        createdAt: now,
      ),
    );

    clearCart();
    return true;
  }

  /// Resumes a previously held order back into the active cart.
  void resumeHeldOrder(String heldId) {
    final idx = _heldOrders.indexWhere((h) => h.id == heldId);
    if (idx < 0) return;

    final held = _heldOrders.removeAt(idx);
    _cartItems
      ..clear()
      ..addAll(held.items);
    _selectedCustomer = held.customer;
    _discount = held.manualDiscount;
    _notes = held.notes;
    _pointsToRedeem = 0;
    notifyListeners();
  }

  /// Cancels/deletes a held order.
  void removeHeldOrder(String heldId) {
    _heldOrders.removeWhere((h) => h.id == heldId);
    notifyListeners();
  }

  // ─── Cart Operations ────────────────────────────────────────

  /// Adds a product to the active cart.
  bool addToCart(ProductModel product, {String variant = ''}) {
    final index = _cartItems.indexWhere(
        (item) => item.productId == product.id && item.variant == variant);

    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      final newQty = currentQty + 1;
      final itemDisc = _cartItems[index].itemDiscount;
      _cartItems[index] = _cartItems[index].copyWith(
        quantity: newQty,
        subtotal:
            ((_cartItems[index].price * newQty) - itemDisc).clamp(0.0, double.infinity),
      );
    } else {
      final chosenVariant = variant.isNotEmpty
          ? variant
          : (product.variants.isNotEmpty ? product.variants.first : '');
      _cartItems.add(TransactionItemModel(
        productId: product.id,
        productName: product.name,
        productCode: product.code,
        variant: chosenVariant,
        price: product.sellingPrice,
        costPrice: product.costPrice,
        quantity: 1,
        unit: product.unit,
        itemDiscount: 0.0,
        subtotal: product.sellingPrice,
      ));
    }

    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Sets per-item discount nominal (Rp) for a product in cart (PRD Section 5.2).
  void setItemDiscount(String productId, double itemDiscountAmount,
      {String? variant}) {
    final index = _cartItems.indexWhere((item) =>
        item.productId == productId &&
        (variant == null || item.variant == variant));
    if (index >= 0) {
      final item = _cartItems[index];
      final gross = item.price * item.quantity;
      final clampedDisc = itemDiscountAmount.clamp(0.0, gross);
      _cartItems[index] = item.copyWith(
        itemDiscount: clampedDisc,
        subtotal: gross - clampedDisc,
      );
      notifyListeners();
    }
  }

  /// Sets absolute quantity for an item.
  bool setItemQuantity(String productId, int newQty, int maxStock) {
    if (newQty <= 0) {
      removeFromCart(productId);
      return true;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = _cartItems[index];
      final gross = item.price * newQty;
      final clampedDisc = item.itemDiscount.clamp(0.0, gross);
      _cartItems[index] = item.copyWith(
        quantity: newQty,
        itemDiscount: clampedDisc,
        subtotal: gross - clampedDisc,
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
        final item = _cartItems[index];
        final gross = item.price * newQty;
        final clampedDisc = item.itemDiscount.clamp(0.0, gross);
        _cartItems[index] = item.copyWith(
          quantity: newQty,
          itemDiscount: clampedDisc,
          subtotal: gross - clampedDisc,
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

  /// Empties the cart and resets active checkout state.
  void clearCart() {
    _cartItems.clear();
    _selectedCustomer = null;
    _selectedPromo = null;
    _pointsToRedeem = 0;
    _discount = 0.0;
    _paymentMethod = 'Cash';
    _splitPayments = [];
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
    _splitPayments = [];
    notifyListeners();
  }

  void setSplitPayments(List<PaymentSplitItem> splits) {
    _splitPayments = splits;
    _paidAmount = splits.fold(0.0, (acc, s) => acc + s.amount);
    if (splits.length > 1) {
      _paymentMethod = splits.map((s) => s.method).join(' + ');
    } else if (splits.length == 1) {
      _paymentMethod = splits.first.method;
    }
    notifyListeners();
  }

  void clearSplitPayments() {
    _splitPayments = [];
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
    String? status,
    String? shiftId,
  }) async {
    if (_cartItems.isEmpty) {
      _errorMessage = 'Keranjang belanja masih kosong!';
      notifyListeners();
      return null;
    }

    final total = calculateTotal(settings);
    final isUnpaidTx = status == AppConstants.statusUnpaid ||
        _paymentMethod == 'Piutang' ||
        _paidAmount < total;

    // Jika status bukan belum lunas/piutang dan bayar kurang
    if (!isUnpaidTx && _paidAmount < total) {
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
      final serviceCharge = calculateServiceCharge(settings);
      final change = calculateChange(settings);
      final effDiscount = calculateEffectiveDiscount(settings);
      final pointsEarned = calculatePointsEarned(settings);

      final List<PaymentSplitItem> finalPayments = _splitPayments.isNotEmpty
          ? _splitPayments
          : [PaymentSplitItem(method: _paymentMethod, amount: _paidAmount)];

      final finalStatus = status ??
          (isUnpaidTx
              ? AppConstants.statusUnpaid
              : AppConstants.statusCompleted);

      final draftTransaction = TransactionModel(
        id: '',
        invoiceNumber: invoiceNumber,
        cashierId: cashier.uid,
        cashierName: cashier.name,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        subtotal: subtotal,
        discount: effDiscount,
        tax: tax,
        serviceCharge: serviceCharge,
        total: total,
        totalCostPrice: totalCostPrice,
        paymentMethod: _paymentMethod,
        payments: finalPayments,
        paidAmount: _paidAmount,
        changeAmount: change,
        pointsEarned: pointsEarned,
        pointsRedeemed: _pointsToRedeem,
        status: finalStatus,
        shiftId: shiftId,
        notes: _notes.trim(),
        items: List<TransactionItemModel>.from(_cartItems),
        createdAt: DateTime.now(),
      );

      final savedId =
          await _transactionService.executeTransaction(draftTransaction);
      final completedTx = draftTransaction.copyWith(id: savedId);

      // Reset cart after successful transaction
      clearCart();
      _isProcessing = false;
      notifyListeners();

      return completedTx;
    } catch (e) {
      _errorMessage = 'Gagal memproses transaksi: $e';
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
