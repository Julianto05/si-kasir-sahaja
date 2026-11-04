import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/shift_model.dart';
import '../models/transaction_model.dart';
import '../services/shift_service.dart';
import 'attendance_provider.dart';

/// Provider for managing cashier shifts, manual petty cash, and shift closing (PRD Section 5.3).
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
        // Keep activeShift in sync if updated or deleted
        if (_activeShift != null) {
          final updated =
              shifts.where((s) => s.id == _activeShift!.id).firstOrNull;
          if (updated != null && updated.isOpen) {
            _activeShift = updated;
          } else {
            _activeShift = null;
          }
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Shift stream error: $e');
      },
    );
  }

  /// Loads or refreshes the active shift for the given cashier or admin.
  Future<void> loadActiveShift(String cashierId) async {
    if (cashierId.isEmpty) return;
    try {
      if (_activeShift != null && _activeShift!.cashierId != cashierId) {
        _activeShift = null;
      }
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

      await AttendanceProvider.logActivity(
        userId: cashierId,
        userName: cashierName,
        action: 'Membuka Shift Kasir (Modal Awal: Rp ${startingCash.toInt()})',
        entity: 'shifts',
        entityId: shift.id,
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

  /// Records manual petty cash in or out during an active shift (PRD Section 5.3).
  Future<bool> addManualCashEntry({
    required bool isCashIn,
    required double amount,
    required String note,
  }) {
    return addPettyCash(
      type: isCashIn ? 'in' : 'out',
      amount: amount,
      reason: note,
    );
  }

  /// Records manual petty cash in or out during an active shift (PRD Section 5.3).
  Future<bool> addPettyCash({
    required String type, // 'in' or 'out'
    required double amount,
    required String reason,
  }) async {
    if (_activeShift == null) return false;
    try {
      _isLoading = true;
      notifyListeners();

      final entry = ShiftCashEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        amount: amount,
        reason: reason.trim(),
        createdAt: DateTime.now(),
      );

      await _shiftService.addPettyCashEntry(
        shiftId: _activeShift!.id,
        entry: entry,
      );

      if (type == 'in') {
        _activeShift = _activeShift!.copyWith(
          cashIn: [..._activeShift!.cashIn, entry],
        );
      } else {
        _activeShift = _activeShift!.copyWith(
          cashOut: [..._activeShift!.cashOut, entry],
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal mencatat kas kecil: $e';
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
    String? shiftId,
  }) async {
    final targetShift = _activeShift ??
        (shiftId != null
            ? _allShifts.where((s) => s.id == shiftId && s.isOpen).firstOrNull
            : null);

    if (targetShift == null) {
      _errorMessage = 'Sesi shift tidak ditemukan atau sudah ditutup.';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Calculate shift totals from actual transactions with unified breakdown
      final breakdown = ShiftSalesBreakdown.compute(shiftTransactions);
      final cashSales = breakdown.cashSales;
      final nonCashSales = breakdown.nonCashSales;
      final totalSales = breakdown.totalSales;
      final transactionCount = breakdown.transactionCount;

      final expectedCash = targetShift.startingCash +
          cashSales +
          targetShift.totalCashIn -
          targetShift.totalCashOut;
      final cashDifference = physicalCash - expectedCash;

      await _shiftService.closeShift(
        shiftId: targetShift.id,
        cashSales: cashSales,
        nonCashSales: nonCashSales,
        totalSales: totalSales,
        transactionCount: transactionCount,
        physicalCash: physicalCash,
        cashDifference: cashDifference,
        denominations: denominations,
        notes: notes,
      );

      await AttendanceProvider.logActivity(
        userId: targetShift.cashierId,
        userName: targetShift.cashierName,
        action:
            'Menutup Shift Kasir (Fisik: Rp ${physicalCash.toInt()}, Selisih: Rp ${cashDifference.toInt()})',
        entity: 'shifts',
        entityId: targetShift.id,
      );

      final closedShift = targetShift.copyWith(
        closedAt: DateTime.now(),
        cashSales: cashSales,
        nonCashSales: nonCashSales,
        totalSales: totalSales,
        transactionCount: transactionCount,
        physicalCash: physicalCash,
        cashDifference: cashDifference,
        denominations: denominations,
        notes: notes,
        status: 'closed',
      );

      if (_activeShift?.id == targetShift.id) {
        _activeShift = null;
      }
      _isLoading = false;
      notifyListeners();
      return closedShift;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menutup shift: $e';
      notifyListeners();
      return null;
    }
  }
}
