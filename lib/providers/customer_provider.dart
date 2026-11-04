import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/customer_model.dart';

/// Provider for managing Customers, Members, and Loyalty Points (`customers` & `point_logs` - PRD Section 4 & 5.8).
class CustomerProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CustomerModel> _customers = [];
  List<PointLogModel> _pointLogs = [];
  String _searchQuery = '';
  bool _onlyMembers = false;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _customerSub;
  StreamSubscription<QuerySnapshot>? _pointSub;

  CustomerProvider() {
    _initStreams();
  }

  List<CustomerModel> get allCustomers => _customers;
  List<CustomerModel> get activeCustomers =>
      _customers.where((c) => c.isActive).toList();
  List<CustomerModel> get memberCustomers =>
      _customers.where((c) => c.isActive && c.isMember).toList();
  List<PointLogModel> get pointLogs => _pointLogs;
  String get searchQuery => _searchQuery;
  bool get onlyMembers => _onlyMembers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CustomerModel> get filteredCustomers {
    return _customers.where((c) {
      if (_onlyMembers && !c.isMember) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        return c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.whatsapp.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    _customerSub = _firestore
        .collection(AppConstants.customersCollection)
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs
                .map((doc) => CustomerModel.fromFirestore(doc))
                .toList();
            list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
            _customers = list;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (e) {
            _isLoading = false;
            _errorMessage = 'Gagal memuat data pelanggan: $e';
            notifyListeners();
          },
        );

    _pointSub = _firestore
        .collection(AppConstants.pointLogsCollection)
        .snapshots()
        .listen((snap) {
          final logs = snap.docs
              .map((doc) => PointLogModel.fromFirestore(doc))
              .toList();
          logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _pointLogs = logs;
          notifyListeners();
        });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleOnlyMembers() {
    _onlyMembers = !_onlyMembers;
    notifyListeners();
  }

  Future<CustomerModel?> saveCustomer({
    required String name,
    required String phone,
    bool isMember = true,
  }) {
    return addCustomer(
      name: name,
      whatsapp: phone,
      address: '',
      isMember: isMember,
    );
  }

  Future<CustomerModel?> addCustomer({
    required String name,
    required String whatsapp,
    required String address,
    bool isMember = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection(AppConstants.customersCollection)
          .doc();
      final seq = (_customers.length + 1).toString().padLeft(4, '0');
      final code = '${isMember ? "MBR" : "PLG"}-$seq';

      final customer = CustomerModel(
        id: docRef.id,
        code: code,
        name: name.trim(),
        whatsapp: whatsapp.trim(),
        address: address.trim(),
        isMember: isMember,
        points: 0,
        totalSpent: 0.0,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await docRef.set(customer.toMap());
      _isLoading = false;
      notifyListeners();
      return customer;
    } catch (e) {
      _errorMessage = 'Gagal menambah pelanggan: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCustomer(CustomerModel customer) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection(AppConstants.customersCollection)
          .doc(customer.id)
          .update(customer.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui pelanggan: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _customerSub?.cancel();
    _pointSub?.cancel();
    super.dispose();
  }
}
