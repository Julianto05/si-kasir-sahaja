import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/shift_model.dart';
import '../models/transaction_model.dart';
import '../services/shift_service.dart';

/// Provider for managing cashier shifts and shift closing (Indomaret style).
class ShiftProvider extends ChangeNotifier {
  final ShiftService _shiftService = ShiftService();

  ShiftModel? _activeShift;
  List<ShiftModel> _allShifts = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<ShiftModel>>? _subscription;

  ShiftModel? get activeShift => _activeShift;
  List<ShiftModel> get allShifts => _allShifts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveShift => _activeShift != null && _activeShift!.isOpen;

  ShiftProvider() {
    _initAdminStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initAdminStream() {
    _subscription = _shiftService.streamAllShifts().listen(
      (shifts) {
        _allShifts = shifts;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Shift stream error: $e');
      },
    );
  }

  /// Loads or refreshes the active shift for the given cashier.
  Future<void> loadActiveShift(String cashierId) async {
    if (cashierId.isEmpty) return;
    try {
      _isLoading = true;
      notifyListeners();

      _activeShift = await _shiftService.getActiveShift(cashierId);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat status shift: $e';
      notifyListeners();
    }
  }

  /// Opens a new shift for the cashier with an initial cash float (modal awal).
  Future<bool> openShift({
    required String cashierId,
    required String cashierName,
    required double startingCash,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final shift = await _shiftService.openShift(
        cashierId: cashierId,
        cashierName: cashierName,
        startingCash: startingCash,
      );

      _activeShift = shift;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal membuka shift: $e';
      notifyListeners();
      return false;
    }
  }

  /// Closes the current active shift and records the physical cash count & variance.
  Future<ShiftModel?> closeCurrentShift({
    required List<TransactionModel> shiftTransactions,
    required double physicalCash,
    required Map<String, int> denominations,
    required String notes,
  }) async {
    if (_activeShift == null) return null;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Calculate shift totals from actual transactions
      double cashSales = 0.0;
      double nonCashSales = 0.0;

      for (final tx in shiftTransactions) {
        if (tx.paymentMethod == 'cash') {
          cashSales += tx.total;
        } else {
          nonCashSales += tx.total;
        }
      }

      final totalSales = cashSales + nonCashSales;
      final expectedCash = _activeShift!.startingCash + cashSales;
      final cashDifference = physicalCash - expectedCash;

      await _shiftService.closeShift(
        shiftId: _activeShift!.id,
        cashSales: cashSales,
        nonCashSales: nonCashSales,
        totalSales: totalSales,
        transactionCount: shiftTransactions.length,
        physicalCash: physicalCash,
        cashDifference: cashDifference,
        denominations: denominations,
        notes: notes,
      );

      final closedShift = _activeShift!.copyWith(
        closedAt: DateTime.now(),
        cashSales: cashSales,
        nonCashSales: nonCashSales,
        totalSales: totalSales,
        transactionCount: shiftTransactions.length,
        physicalCash: physicalCash,
        cashDifference: cashDifference,
        denominations: denominations,
        notes: notes,
        status: 'closed',
      );

      _activeShift = null;
      _isLoading = false;
      notifyListeners();
      return closedShift;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal melakukan closing shift: $e';
      notifyListeners();
      return null;
    }
  }
}
