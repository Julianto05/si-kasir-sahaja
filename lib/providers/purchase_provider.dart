import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/finance_model.dart';
import '../models/supplier_model.dart';

/// Provider for managing Supplier Purchases / Goods Receipts (`purchases` - PRD Section 4 & 5.7).
///
/// Uses Firestore Batched Writes to atomically:
/// 1. Record the purchase order
/// 2. Increment product stock & update product `costPrice` (harga modal)
/// 3. Record `purchase_in` stock movement logs
/// 4. Record supplier payable (`debts`) if `paidAmount < total`
class PurchaseProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<PurchaseModel> _purchases = [];
  String _selectedSupplierId = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _subscription;

  PurchaseProvider() {
    _initStream();
  }

  List<PurchaseModel> get allPurchases => _purchases;
  String get selectedSupplierId => _selectedSupplierId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalPurchasesAmount =>
      _purchases.fold(0.0, (acc, p) => acc + p.total);

  double get totalUnpaidPurchases =>
      _purchases.fold(0.0, (acc, p) => acc + p.remainingDebt);

  List<PurchaseModel> get filteredPurchases {
    return _purchases.where((p) {
      if (_selectedSupplierId != 'all' && p.supplierId != _selectedSupplierId) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        return p.purchaseNo.toLowerCase().contains(q) ||
            p.supplierName.toLowerCase().contains(q) ||
            p.notes.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection(AppConstants.purchasesCollection)
        .snapshots()
        .listen(
      (snap) {
        final list =
            snap.docs.map((doc) => PurchaseModel.fromFirestore(doc)).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        _purchases = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat riwayat pembelian: $e';
        notifyListeners();
      },
    );
  }

  void setSupplierFilter(String supplierId) {
    _selectedSupplierId = supplierId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Creates a new purchase order and receives stock atomically using Firestore Batched Writes.
  Future<bool> createPurchase({
    required String supplierId,
    required String supplierName,
    required List<PurchaseItemModel> items,
    required double paidAmount,
    required String notes,
    required String userId,
    required String userName,
    DateTime? dueDate,
  }) async {
    if (items.isEmpty) {
      _errorMessage = 'Daftar barang pembelian masih kosong!';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd').format(now);
      final randomSuffix =
          (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final purchaseNo = 'PO-$dateStr-$randomSuffix';

      final total = items.fold(0.0, (acc, item) => acc + item.subtotal);
      final clampedPaid = paidAmount.clamp(0.0, total);
      final String paymentStatus = clampedPaid >= total
          ? 'paid'
          : (clampedPaid > 0 ? 'partial' : 'unpaid');

      final batch = _firestore.batch();

      // 1. Purchase Document
      final purchaseRef =
          _firestore.collection(AppConstants.purchasesCollection).doc();
      final purchase = PurchaseModel(
        id: purchaseRef.id,
        purchaseNo: purchaseNo,
        supplierId: supplierId,
        supplierName: supplierName,
        date: now,
        items: items,
        total: total,
        paidAmount: clampedPaid,
        paymentStatus: paymentStatus,
        notes: notes,
        createdBy: userId,
        createdByName: userName,
        createdAt: now,
      );
      batch.set(purchaseRef, purchase.toMap());

      // 2. Increment product stock & update costPrice + create stock_movements
      for (final item in items) {
        final prodRef = _firestore
            .collection(AppConstants.productsCollection)
            .doc(item.productId);
        batch.update(prodRef, {
          'stock': FieldValue.increment(item.qty),
          'costPrice': item.buyPrice,
          'updatedAt': Timestamp.fromDate(now),
        });

        final movRef = _firestore
            .collection(AppConstants.stockMovementsCollection)
            .doc();
        batch.set(movRef, {
          'productId': item.productId,
          'productName': item.productName,
          'productCode': item.productCode,
          'type': AppConstants.stockPurchaseIn,
          'quantity': item.qty,
          'stockBefore': 0,
          'stockAfter': 0,
          'notes': 'Pembelian $purchaseNo dari $supplierName',
          'userId': userId,
          'userName': userName,
          'createdAt': Timestamp.fromDate(now),
        });
      }

      // 3. If not fully paid, create Supplier Payable (Utang Supplier) in `debts`
      if (clampedPaid < total) {
        final debtRef =
            _firestore.collection(AppConstants.debtsCollection).doc();
        final debt = DebtModel(
          id: debtRef.id,
          type: 'utang',
          partyType: 'supplier',
          partyId: supplierId,
          partyName: supplierName,
          referenceNo: purchaseNo,
          amount: total,
          paidAmount: clampedPaid,
          dueDate: dueDate ?? now.add(const Duration(days: 14)),
          status: paymentStatus,
          notes: 'Utang Pembelian $purchaseNo. $notes'.trim(),
          createdAt: now,
        );
        batch.set(debtRef, debt.toMap());
      }

      // 4. Activity Audit Log
      final logRef =
          _firestore.collection(AppConstants.activityLogsCollection).doc();
      batch.set(logRef, {
        'userId': userId,
        'userName': userName,
        'action': 'Membuat Pembelian Barang $purchaseNo ($supplierName)',
        'entity': 'purchases',
        'entityId': purchaseRef.id,
        'createdAt': Timestamp.fromDate(now),
      });

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan pembelian: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

