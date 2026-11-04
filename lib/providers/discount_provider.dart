import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/discount_model.dart';

/// Provider for managing Discounts & Promos (`discounts` - PRD Section 4 & 5.11).
class DiscountProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DiscountModel> _discounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot>? _subscription;

  DiscountProvider() {
    _initStream();
  }

  List<DiscountModel> get allDiscounts => _discounts;
  List<DiscountModel> get validDiscounts =>
      _discounts.where((d) => d.isValidNow).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _firestore
        .collection(AppConstants.discountsCollection)
        .snapshots()
        .listen(
      (snap) {
        final list =
            snap.docs.map((doc) => DiscountModel.fromFirestore(doc)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _discounts = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data diskon: $e';
        notifyListeners();
      },
    );
  }

  Future<bool> addDiscount(DiscountModel discount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef =
          _firestore.collection(AppConstants.discountsCollection).doc();
      await docRef.set(discount.copyWith(id: docRef.id).toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menambah diskon/promo: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDiscount(DiscountModel discount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection(AppConstants.discountsCollection)
          .doc(discount.id)
          .update(discount.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui diskon: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDiscount(String id) async {
    try {
      await _firestore
          .collection(AppConstants.discountsCollection)
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus diskon: $e';
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

