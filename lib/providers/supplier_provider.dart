import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/supplier_model.dart';

/// Provider for managing Suppliers (`suppliers` collection - PRD Section 4 & 5.7).
class SupplierProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<SupplierModel> _suppliers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _subscription;

  SupplierProvider() {
    _initStream();
  }

  List<SupplierModel> get allSuppliers => _suppliers;
  List<SupplierModel> get activeSuppliers =>
      _suppliers.where((s) => s.isActive).toList();
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<SupplierModel> get filteredSuppliers {
    if (_searchQuery.trim().isEmpty) return _suppliers;
    final q = _searchQuery.toLowerCase().trim();
    return _suppliers.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.phone.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
    }).toList();
  }

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection(AppConstants.suppliersCollection)
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs
                .map((doc) => SupplierModel.fromFirestore(doc))
                .toList();
            list.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
            _suppliers = list;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (e) {
            _isLoading = false;
            _errorMessage = 'Gagal memuat data supplier: $e';
            notifyListeners();
          },
        );
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> addSupplier({
    required String name,
    required String phone,
    required String address,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection(AppConstants.suppliersCollection)
          .doc();
      final supplier = SupplierModel(
        id: docRef.id,
        name: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        isActive: isActive,
        createdAt: DateTime.now(),
      );
      await docRef.set(supplier.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan supplier: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier(SupplierModel supplier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection(AppConstants.suppliersCollection)
          .doc(supplier.id)
          .update(supplier.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui supplier: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleSupplierStatus(SupplierModel supplier) async {
    return updateSupplier(supplier.copyWith(isActive: !supplier.isActive));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
