import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';

/// Service for deleting operational store data (transactions, shifts, expenses,
/// purchases, attendance, debts, activity logs, etc.) based on specified time range or criteria.
class DataResetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper to batch delete documents from a query.
  Future<int> _deleteQueryDocs(QuerySnapshot snapshot) async {
    int deleted = 0;
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      batchCount++;
      deleted++;

      if (batchCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      await batch.commit();
    }
    return deleted;
  }

  /// Deletes operational data across collections within the specified date range.
  Future<int> resetData({
    required DateTime startDate,
    required DateTime endDate,
    bool deleteTransactions = true,
    bool deleteStockMovements = true,
    bool deleteShifts = true,
    bool deleteExpenses = false,
    bool deletePurchases = false,
    bool deleteDebts = false,
    bool deleteAttendanceLogs = false,
    bool deleteActivityLogs = false,
    bool deletePointLogs = false,
    bool resetCustomerPoints = false,
    bool resetProductStock = false,
  }) async {
    int totalDeleted = 0;

    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(endDate);

    // 1. Delete Transactions (including items subcollection)
    if (deleteTransactions) {
      final txQuery = await _firestore
          .collection(AppConstants.transactionsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      for (final doc in txQuery.docs) {
        final itemsSnap = await doc.reference
            .collection(AppConstants.transactionItemsSubcollection)
            .get();

        WriteBatch batch = _firestore.batch();
        int batchCount = 0;

        for (final itemDoc in itemsSnap.docs) {
          batch.delete(itemDoc.reference);
          batchCount++;
          if (batchCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
        if (batchCount > 0) {
          await batch.commit();
        }

        await doc.reference.delete();
        totalDeleted++;
      }
    }

    // 2. Delete Stock Movements
    if (deleteStockMovements) {
      final movementsQuery = await _firestore
          .collection(AppConstants.stockMovementsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      totalDeleted += await _deleteQueryDocs(movementsQuery);
    }

    // 3. Delete Shifts
    if (deleteShifts) {
      final shiftsQuery = await _firestore
          .collection(AppConstants.shiftsCollection)
          .where('openedAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('openedAt', isLessThanOrEqualTo: endTimestamp)
          .get();

      totalDeleted += await _deleteQueryDocs(shiftsQuery);
    }

    // 4. Delete Expenses & Capital Entries (Pengeluaran & Modal)
    if (deleteExpenses) {
      final expensesQuery = await _firestore
          .collection(AppConstants.expensesCollection)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(expensesQuery);

      final capitalQuery = await _firestore
          .collection(AppConstants.capitalEntriesCollection)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(capitalQuery);
    }

    // 5. Delete Purchases & Purchase Returns (Pembelian Supplier)
    if (deletePurchases) {
      final purchasesQuery = await _firestore
          .collection(AppConstants.purchasesCollection)
          .where('purchaseDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('purchaseDate', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(purchasesQuery);

      final purchaseReturnsQuery = await _firestore
          .collection(AppConstants.purchaseReturnsCollection)
          .where('returnDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('returnDate', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(purchaseReturnsQuery);
    }

    // 6. Delete Debts & Debt Payments (Catatan Hutang & Piutang)
    if (deleteDebts) {
      final debtsQuery = await _firestore
          .collection(AppConstants.debtsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(debtsQuery);

      final debtPaymentsQuery = await _firestore
          .collection(AppConstants.debtPaymentsCollection)
          .where('paymentDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('paymentDate', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(debtPaymentsQuery);
    }

    // 7. Delete Attendance Logs (Riwayat Presensi & Absensi Karyawan)
    if (deleteAttendanceLogs) {
      final attendanceQuery = await _firestore
          .collection(AppConstants.attendanceLogsCollection)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(attendanceQuery);
    }

    // 8. Delete Activity Logs (Audit Log Aktivitas)
    if (deleteActivityLogs) {
      final activityQuery = await _firestore
          .collection(AppConstants.activityLogsCollection)
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(activityQuery);
    }

    // 9. Delete Point Logs (Riwayat Mutasi Poin Pelanggan)
    if (deletePointLogs) {
      final pointLogsQuery = await _firestore
          .collection(AppConstants.pointLogsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();
      totalDeleted += await _deleteQueryDocs(pointLogsQuery);
    }

    // 10. Reset Customer Points back to 0
    if (resetCustomerPoints) {
      final customersQuery = await _firestore
          .collection(AppConstants.customersCollection)
          .get();

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in customersQuery.docs) {
        batch.update(doc.reference, {
          'points': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
      if (batchCount > 0) {
        await batch.commit();
      }
    }

    // 11. Optionally reset product stock to 0
    if (resetProductStock) {
      final prodsQuery = await _firestore
          .collection(AppConstants.productsCollection)
          .get();

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in prodsQuery.docs) {
        batch.update(doc.reference, {
          'stock': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
      if (batchCount > 0) {
        await batch.commit();
      }
    }

    return totalDeleted;
  }
}
