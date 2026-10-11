import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/transaction_model.dart';

/// Service layer for executing POS transactions, stock reductions, and refunds atomically.
class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection(AppConstants.transactionsCollection);

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection(AppConstants.productsCollection);

  CollectionReference<Map<String, dynamic>> get _movementsRef =>
      _firestore.collection(AppConstants.stockMovementsCollection);

  /// Generates a sequential invoice number like `TRX-20260901-0001`.
  Future<String> generateInvoiceNumber([String prefix = 'TRX']) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final countSnap = await _transactionsRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .count()
        .get();

    final sequence = (countSnap.count ?? 0) + 1;
    return '$prefix-$dateStr-${sequence.toString().padLeft(4, '0')}';
  }

  /// Streams transactions with safe in-memory sorting.
  Stream<List<TransactionModel>> streamTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? cashierId,
    String? status,
  }) {
    return _transactionsRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .where((tx) {
        if (startDate != null && tx.createdAt.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && tx.createdAt.isAfter(endDate)) {
          return false;
        }
        if (cashierId != null &&
            cashierId.isNotEmpty &&
            cashierId != 'all' &&
            tx.cashierId != cashierId) {
          return false;
        }
        if (status != null &&
            status.isNotEmpty &&
            status != 'all' &&
            tx.status != status) {
          return false;
        }
        return true;
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Fetches subcollection items for a given transaction.
  Future<List<TransactionItemModel>> getTransactionItems(
      String transactionId) async {
    final snap = await _transactionsRef
        .doc(transactionId)
        .collection(AppConstants.transactionItemsSubcollection)
        .get();

    return snap.docs
        .map((doc) => TransactionItemModel.fromMap(doc.data()))
        .toList();
  }

  /// Processes and executes a sale transaction atomically.
  ///
  /// 1. Saves transaction document.
  /// 2. Saves all transaction items in subcollection.
  /// 3. Decrements product stock (`stock -= qty`).
  /// 4. Logs a stock movement record for each product.
  Future<String> executeTransaction(TransactionModel transaction) async {
    final batch = _firestore.batch();
    final newTxRef = _transactionsRef.doc();
    final now = DateTime.now();

    // 1. Transaction Document
    final txData = transaction.copyWith(id: newTxRef.id).toMap();
    batch.set(newTxRef, txData);

    // 2. Transaction Items in subcollection + stock updates
    for (final item in transaction.items) {
      final itemRef = newTxRef
          .collection(AppConstants.transactionItemsSubcollection)
          .doc();
      batch.set(itemRef, item.toMap());

      // 3. Atomically decrement product stock
      final productRef = _productsRef.doc(item.productId);
      batch.update(productRef, {
        'stock': FieldValue.increment(-item.quantity),
        'updatedAt': Timestamp.fromDate(now),
      });

      // 4. Log stock movement
      final movementRef = _movementsRef.doc();
      batch.set(movementRef, {
        'productId': item.productId,
        'productName': item.productName,
        'productCode': item.productCode,
        'type': AppConstants.stockSale,
        'quantity': item.quantity,
        'stockBefore': 0, // Recorded in audit
        'stockAfter': 0,
        'notes': 'Penjualan Nota ${transaction.invoiceNumber}',
        'userId': transaction.cashierId,
        'userName': transaction.cashierName,
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
    return newTxRef.id;
  }

  /// Cancels / refunds a transaction (Admin only).
  ///
  /// Atomically:
  /// 1. Updates transaction status to 'cancelled'.
  /// 2. Restores product stocks (`stock += qty`).
  /// 3. Records stock movements with type 'refund'.
  Future<void> cancelTransaction({
    required TransactionModel transaction,
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final txRef = _transactionsRef.doc(transaction.id);

    // 1. Update transaction status
    batch.update(txRef, {
      'status': AppConstants.statusCancelled,
      'cancelReason': reason,
      'cancelledBy': adminName,
      'cancelledAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // 2. Fetch items if not preloaded
    List<TransactionItemModel> items = transaction.items;
    if (items.isEmpty) {
      items = await getTransactionItems(transaction.id);
    }

    // 3. Return stock to products & record movement
    for (final item in items) {
      final productRef = _productsRef.doc(item.productId);
      batch.update(productRef, {
        'stock': FieldValue.increment(item.quantity),
        'updatedAt': Timestamp.fromDate(now),
      });

      final movementRef = _movementsRef.doc();
      batch.set(movementRef, {
        'productId': item.productId,
        'productName': item.productName,
        'productCode': item.productCode,
        'type': AppConstants.stockRefund,
        'quantity': item.quantity,
        'stockBefore': 0,
        'stockAfter': 0,
        'notes': 'Refund Nota ${transaction.invoiceNumber}: $reason',
        'userId': adminId,
        'userName': adminName,
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }
}
