import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shift_model.dart';

/// Firestore Service managing Cashier Shifts, Petty Cash In/Out, and Closing records (PRD Section 5.3).
class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'shifts';

  /// Opens a new cashier work shift.
  Future<ShiftModel> openShift({
    required String cashierId,
    required String cashierName,
    required double startingCash,
  }) async {
    // If there is any dangling open shift for this cashier, safely close its status
    // without overwriting any recorded financial figures
    try {
      final existingOpen = await getActiveShift(cashierId);
      if (existingOpen != null) {
        await _firestore.collection(_collection).doc(existingOpen.id).update({
          'status': 'closed',
          'closedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    final docRef = _firestore.collection(_collection).doc();
    final shift = ShiftModel(
      id: docRef.id,
      cashierId: cashierId,
      cashierName: cashierName,
      openedAt: DateTime.now(),
      startingCash: startingCash,
      status: 'open',
    );

    await docRef.set(shift.toMap());
    return shift;
  }

  /// Adds a manual petty cash entry (Kas Masuk / Kas Keluar) during an active shift.
  Future<void> addPettyCashEntry({
    required String shiftId,
    required ShiftCashEntry entry,
  }) async {
    final docRef = _firestore.collection(_collection).doc(shiftId);
    final fieldName = entry.type == 'in' ? 'cashIn' : 'cashOut';
    await docRef.update({
      fieldName: FieldValue.arrayUnion([entry.toMap()]),
    });
  }

  /// Closes an existing shift with final cash counting and variance calculation.
  Future<void> closeShift({
    required String shiftId,
    required double cashSales,
    required double nonCashSales,
    required double totalSales,
    required int transactionCount,
    required double physicalCash,
    required double cashDifference,
    double physicalNonCash = 0.0,
    int nonCashReceiptCount = 0,
    double nonCashDifference = 0.0,
    required Map<String, int> denominations,
    required String notes,
  }) async {
    final docRef = _firestore.collection(_collection).doc(shiftId);
    await docRef.update({
      'closedAt': FieldValue.serverTimestamp(),
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'totalSales': totalSales,
      'transactionCount': transactionCount,
      'physicalCash': physicalCash,
      'cashDifference': cashDifference,
      'physicalNonCash': physicalNonCash,
      'nonCashReceiptCount': nonCashReceiptCount,
      'nonCashDifference': nonCashDifference,
      'denominations': denominations,
      'notes': notes,
      'status': 'closed',
    });
  }

  /// Gets the currently open shift for a specific cashier or admin,
  /// with a store-wide active shift fallback.
  Future<ShiftModel?> getActiveShift(String cashierId) async {
    if (cashierId.isNotEmpty) {
      final query = await _firestore
          .collection(_collection)
          .where('cashierId', isEqualTo: cashierId)
          .get();

      final openShifts = <ShiftModel>[];
      for (final doc in query.docs) {
        try {
          final s = ShiftModel.fromFirestore(doc);
          if (s.isOpen) openShifts.add(s);
        } catch (_) {}
      }
      if (openShifts.isNotEmpty) {
        openShifts.sort((a, b) => b.openedAt.compareTo(a.openedAt));
        return openShifts.first;
      }
    }

    // Fallback: check if there is an active open shift in the store
    final allOpenQuery = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .get();

    final allOpen = <ShiftModel>[];
    for (final doc in allOpenQuery.docs) {
      try {
        final s = ShiftModel.fromFirestore(doc);
        if (s.isOpen) allOpen.add(s);
      } catch (_) {}
    }
    if (allOpen.isNotEmpty) {
      allOpen.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return allOpen.first;
    }

    return null;
  }

  /// Real-time stream of all shift records for Admin monitoring.
  Stream<List<ShiftModel>> streamAllShifts() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final list = <ShiftModel>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(ShiftModel.fromFirestore(doc));
        } catch (_) {}
      }
      list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return list;
    });
  }
}
