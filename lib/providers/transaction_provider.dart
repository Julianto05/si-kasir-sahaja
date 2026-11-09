import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/transaction_service.dart';

/// Provider for managing transactions history, analytics metrics, and refunds.
class TransactionProvider extends ChangeNotifier {
  final TransactionService _transactionService = TransactionService();

  List<TransactionModel> _transactions = [];
  String _selectedCashierId = 'all';
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _quickDateFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<TransactionModel>>? _subscription;

  TransactionProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCashierId => _selectedCashierId;
  String get selectedStatus => _selectedStatus;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get quickDateFilter => _quickDateFilter;
  String get searchQuery => _searchQuery;

  List<TransactionModel> get allTransactions => _transactions;

  /// Filtered list of transactions based on search, date, cashier, and status.
  List<TransactionModel> get filteredTransactions {
    return _transactions.where((tx) {
      // Cashier filter
      if (_selectedCashierId != 'all' && tx.cashierId != _selectedCashierId) {
        return false;
      }

      // Status filter
      if (_selectedStatus != 'all' && tx.status != _selectedStatus) {
        return false;
      }

      // Date range filter
      if (_startDate != null && tx.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && tx.createdAt.isAfter(_endDate!)) {
        return false;
      }

      // Search query (Invoice number, cashier name, customer notes)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchInvoice = tx.invoiceNumber.toLowerCase().contains(q);
        final matchCashier = tx.cashierName.toLowerCase().contains(q);
        final matchNotes = tx.notes.toLowerCase().contains(q);
        if (!matchInvoice && !matchCashier && !matchNotes) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ─── Metrics for Reports & Dashboard ────────────────────────

  /// Completed transactions within current filter.
  List<TransactionModel> get completedTransactions =>
      filteredTransactions.where((tx) => tx.isCompleted).toList();

  /// Total Revenue (Gross Sales) from completed transactions.
  double get totalRevenue =>
      completedTransactions.fold(0.0, (sum, tx) => sum + tx.total);

  /// Total Net Profit from completed transactions.
  double get totalProfit =>
      completedTransactions.fold(0.0, (sum, tx) => sum + tx.profit);

  /// Total COGS (Cost of Goods Sold).
  double get totalCost =>
      completedTransactions.fold(0.0, (sum, tx) => sum + tx.totalCostPrice);

  /// Total count of items sold.
  int get totalItemsSold =>
      completedTransactions.fold(0, (sum, tx) => sum + tx.totalItemCount);

  /// Today's completed transactions.
  List<TransactionModel> get todayTransactions {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _transactions.where((tx) {
      return tx.isCompleted && tx.createdAt.isAfter(startOfToday);
    }).toList();
  }

  double get todaySales =>
      todayTransactions.fold(0.0, (sum, tx) => sum + tx.total);

  int get todayTransactionCount => todayTransactions.length;

  int get todayItemsSold =>
      todayTransactions.fold(0, (sum, tx) => sum + tx.totalItemCount);

  // ─── Stream Initialization ──────────────────────────────────

  Timer? _reconnectTimer;

  void _initStream() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _transactionService.streamTransactions().listen(
      (transactions) {
        _transactions = transactions;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat riwayat transaksi: $error';
        notifyListeners();
        // Schedule auto reconnect if stream failed
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 4), () {
          _initStream();
        });
      },
    );
  }

  /// Manually re-initializes transaction subscription.
  void refreshTransactions() {
    _initStream();
  }

  // ─── Filters ────────────────────────────────────────────────

  void setCashierFilter(String cashierId) {
    _selectedCashierId = cashierId;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _quickDateFilter = 'custom';
    _startDate = start;
    _endDate = end != null
        ? DateTime(end.year, end.month, end.day, 23, 59, 59)
        : null;
    notifyListeners();
  }

  void setQuickDateFilter(String range) {
    _quickDateFilter = range;
    final now = DateTime.now();
    switch (range) {
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'all':
      default:
        _quickDateFilter = 'all';
        _startDate = null;
        _endDate = null;
    }
    notifyListeners();
  }

  void resetFilters() {
    _selectedCashierId = 'all';
    _selectedStatus = 'all';
    _searchQuery = '';
    _quickDateFilter = 'all';
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  // ─── Refund / Cancellation ──────────────────────────────────

  /// Cancels a transaction and restores inventory.
  Future<bool> cancelTransaction({
    required TransactionModel transaction,
    required String reason,
    required UserModel admin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _transactionService.cancelTransaction(
        transaction: transaction,
        reason: reason,
        adminId: admin.uid,
        adminName: admin.name,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan transaksi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Settles an unpaid transaction to completed status.
  Future<bool> settleTransaction({
    required TransactionModel transaction,
    required double additionalPaidAmount,
    required String paymentMethod,
    String notes = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _transactionService.settleUnpaidTransaction(
        transaction: transaction,
        additionalPaidAmount: additionalPaidAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat pelunasan transaksi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates transaction status and syncs with debts collection.
  Future<bool> updateTransactionStatus({
    required TransactionModel transaction,
    required String newStatus,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _transactionService.updateTransactionStatus(
        transaction: transaction,
        newStatus: newStatus,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui status transaksi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetches subcollection items for detail views.
  Future<List<TransactionItemModel>> getTransactionItems(
    String transactionId,
  ) async {
    return await _transactionService.getTransactionItems(transactionId);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
