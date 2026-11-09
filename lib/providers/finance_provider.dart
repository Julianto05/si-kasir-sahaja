import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/finance_model.dart';

/// Provider for managing Operational Expenses, Capital Entries, and Payables/Receivables (`expenses`, `capital_entries`, `debts`, `debt_payments` - PRD Section 4 & 5.9).
class FinanceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ExpenseModel> _expenses = [];
  List<CapitalEntryModel> _capitalEntries = [];
  List<DebtModel> _debts = [];
  List<DebtPaymentModel> _debtPayments = [];

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _expenseSub;
  StreamSubscription<QuerySnapshot>? _capitalSub;
  StreamSubscription<QuerySnapshot>? _debtSub;
  StreamSubscription<QuerySnapshot>? _debtPaymentSub;

  FinanceProvider() {
    _initStreams();
  }

  List<ExpenseModel> get allExpenses => _expenses;
  List<CapitalEntryModel> get allCapitalEntries => _capitalEntries;
  List<DebtModel> get allDebts => _debts;
  List<DebtPaymentModel> get allDebtPayments => _debtPayments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Supplier Payables (Utang Supplier)
  List<DebtModel> get supplierDebts =>
      _debts.where((d) => d.type == 'utang').toList();

  /// Customer Receivables (Piutang Pelanggan)
  List<DebtModel> get customerReceivables =>
      _debts.where((d) => d.type == 'piutang').toList();

  double get totalExpenses => _expenses.fold(0.0, (acc, e) => acc + e.amount);

  double get todayExpenses {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _expenses
        .where((e) => !e.date.isBefore(startOfToday))
        .fold(0.0, (acc, e) => acc + e.amount);
  }

  double expensesInRange(DateTime? start, DateTime? end) {
    return _expenses
        .where((e) {
          if (start != null && e.date.isBefore(start)) return false;
          if (end != null && e.date.isAfter(end)) return false;
          return true;
        })
        .fold(0.0, (acc, e) => acc + e.amount);
  }

  double get totalCapital =>
      _capitalEntries.fold(0.0, (acc, c) => acc + c.amount);

  double get totalUnpaidSupplierDebt =>
      supplierDebts.fold(0.0, (acc, d) => acc + d.remainingAmount);

  double get totalUnpaidCustomerReceivable =>
      customerReceivables.fold(0.0, (acc, d) => acc + d.remainingAmount);

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    _expenseSub = _firestore
        .collection(AppConstants.expensesCollection)
        .snapshots()
        .listen((snap) {
          final list = snap.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          _expenses = list;
          _isLoading = false;
          notifyListeners();
        });

    _capitalSub = _firestore
        .collection(AppConstants.capitalEntriesCollection)
        .snapshots()
        .listen((snap) {
          final list = snap.docs
              .map((doc) => CapitalEntryModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          _capitalEntries = list;
          notifyListeners();
        });

    _debtSub = _firestore
        .collection(AppConstants.debtsCollection)
        .snapshots()
        .listen((snap) {
          final list = snap.docs
              .map((doc) => DebtModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _debts = list;
          notifyListeners();
        });

    _debtPaymentSub = _firestore
        .collection(AppConstants.debtPaymentsCollection)
        .snapshots()
        .listen((snap) {
          final list = snap.docs
              .map((doc) => DebtPaymentModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          _debtPayments = list;
          notifyListeners();
        });
  }

  /// Cancels existing subscriptions and re-subscribes to all finance streams.
  void refreshFinance() {
    _expenseSub?.cancel();
    _capitalSub?.cancel();
    _debtSub?.cancel();
    _debtPaymentSub?.cancel();
    _initStreams();
  }

  Future<bool> addExpense({
    required String category,
    required double amount,
    required String note,
    required DateTime date,
    required String userId,
    required String userName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection(AppConstants.expensesCollection)
          .doc();
      final expense = ExpenseModel(
        id: docRef.id,
        category: category,
        amount: amount,
        note: note,
        date: date,
        createdBy: userId,
        createdByName: userName,
      );
      await docRef.set(expense.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat pengeluaran: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      await _firestore
          .collection(AppConstants.expensesCollection)
          .doc(expenseId)
          .delete();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus pengeluaran: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCapitalEntry({
    required double amount,
    required String note,
    required DateTime date,
    required String userId,
    required String userName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection(AppConstants.capitalEntriesCollection)
          .doc();
      final entry = CapitalEntryModel(
        id: docRef.id,
        amount: amount,
        note: note,
        date: date,
        createdBy: userId,
        createdByName: userName,
      );
      await docRef.set(entry.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat modal usaha: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Adds a manual Debt or Receivable entry into `debts`.
  Future<bool> addManualDebt({
    required String type,
    required String partyName,
    required String referenceNo,
    required double amount,
    DateTime? dueDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docRef = _firestore.collection(AppConstants.debtsCollection).doc();
      final debt = DebtModel(
        id: docRef.id,
        type: type,
        partyType: type == 'utang' ? 'supplier' : 'customer',
        partyId: 'manual',
        partyName: partyName.trim(),
        referenceNo: referenceNo.trim().isEmpty ? 'MANUAL' : referenceNo.trim(),
        amount: amount,
        paidAmount: 0.0,
        dueDate: dueDate ?? DateTime.now().add(const Duration(days: 14)),
        status: 'unpaid',
        createdAt: DateTime.now(),
      );
      await docRef.set(debt.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat utang/piutang: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Pays an installment or full amount of a Debt (`debts` + `debt_payments`) atomically.
  Future<bool> payDebt({
    required DebtModel debt,
    required double payAmount,
    required String method,
    required String note,
    required String userId,
    required String userName,
  }) async {
    if (payAmount <= 0) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      final newPaid = (debt.paidAmount + payAmount).clamp(0.0, debt.amount);
      final newStatus = newPaid >= debt.amount ? 'paid' : 'partial';

      final debtRef = _firestore
          .collection(AppConstants.debtsCollection)
          .doc(debt.id);
      batch.update(debtRef, {'paidAmount': newPaid, 'status': newStatus});

      final paymentRef = _firestore
          .collection(AppConstants.debtPaymentsCollection)
          .doc();
      final payment = DebtPaymentModel(
        id: paymentRef.id,
        debtId: debt.id,
        amount: payAmount,
        method: method,
        note: note,
        date: now,
        createdBy: userId,
        createdByName: userName,
      );
      batch.set(paymentRef, payment.toMap());

      // Jika ini pelunasan piutang pelanggan dari nota transaksi POS, sinkronkan status transaksi di transactions
      if (debt.type == 'piutang' && debt.referenceNo.isNotEmpty) {
        final txSnap = await _firestore
            .collection(AppConstants.transactionsCollection)
            .where('invoiceNumber', isEqualTo: debt.referenceNo)
            .limit(1)
            .get();

        if (txSnap.docs.isNotEmpty) {
          final txDoc = txSnap.docs.first;
          final currentTxPaid =
              (txDoc.data()['paidAmount'] as num?)?.toDouble() ?? 0.0;
          final txTotal =
              (txDoc.data()['total'] as num?)?.toDouble() ?? debt.amount;
          final updatedTxPaid = (currentTxPaid + payAmount).clamp(0.0, txTotal);
          final updatedTxStatus = newStatus == 'paid'
              ? AppConstants.statusCompleted
              : AppConstants.statusUnpaid;

          batch.update(txDoc.reference, {
            'paidAmount': updatedTxPaid,
            'status': updatedTxStatus,
            'updatedAt': Timestamp.fromDate(now),
          });
        }
      }

      await batch.commit();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat pembayaran utang/piutang: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _expenseSub?.cancel();
    _capitalSub?.cancel();
    _debtSub?.cancel();
    _debtPaymentSub?.cancel();
    super.dispose();
  }
}
