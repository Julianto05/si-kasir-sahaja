import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shift_model.dart';

/// Firestore Service managing Cashier Shifts and Closing records.
class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'shifts';

  /// Opens a new cashier work shift.
  Future<ShiftModel> openShift({
    required String cashierId,
    required String cashierName,
    required double startingCash,
  }) async {
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

  /// Closes an existing shift with final cash counting and variance calculation.
  Future<void> closeShift({
    required String shiftId,
    required double cashSales,
    required double nonCashSales,
    required double totalSales,
    required int transactionCount,
    required double physicalCash,
    required double cashDifference,
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
      'denominations': denominations,
      'notes': notes,
      'status': 'closed',
    });
  }

  /// Gets the currently open shift for a specific cashier.
  Future<ShiftModel?> getActiveShift(String cashierId) async {
    final query = await _firestore
        .collection(_collection)
        .where('cashierId', isEqualTo: cashierId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return ShiftModel.fromFirestore(query.docs.first);
  }

  /// Real-time stream of all shift records for Admin monitoring.
  Stream<List<ShiftModel>> streamAllShifts() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ShiftModel.fromFirestore(doc))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return list;
    });
  }
}
