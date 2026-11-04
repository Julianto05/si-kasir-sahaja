import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/transaction_model.dart';

/// Service layer for executing POS transactions, stock reductions, loyalty points,
/// customer receivables (piutang), and refunds atomically (PRD Section 5.2, 5.8, 5.9 & 7).
class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection(AppConstants.transactionsCollection);

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection(AppConstants.productsCollection);

  CollectionReference<Map<String, dynamic>> get _movementsRef =>
      _firestore.collection(AppConstants.stockMovementsCollection);

  /// Generates a sequential invoice number like `TRX-20261103-0001`.
  Future<String> generateInvoiceNumber([String prefix = 'TRX']) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final countSnap = await _transactionsRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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

  /// Processes and executes a sale transaction atomically using Firestore Batched Writes.
  ///
  /// 1. Saves transaction document.
  /// 2. Saves all transaction items in subcollection.
  /// 3. Decrements product stock (`stock -= qty`).
  /// 4. Logs a stock movement record for each product.
  /// 5. Updates customer `totalSpent` and `points` + logs `point_logs` if customer is attached.
  /// 6. Records customer receivable (`debts` type `'piutang'`) if payment includes `'Piutang'`.
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
        'stockBefore': 0,
        'stockAfter': 0,
        'notes': 'Penjualan Nota ${transaction.invoiceNumber}',
        'userId': transaction.cashierId,
        'userName': transaction.cashierName,
        'createdAt': Timestamp.fromDate(now),
      });
    }

    // 5. Customer Loyalty Points & Total Spent Update (PRD Section 5.8)
    if (transaction.customerId != null && transaction.customerId!.isNotEmpty) {
      final custRef = _firestore
          .collection(AppConstants.customersCollection)
          .doc(transaction.customerId);
      final netPointsDelta =
          transaction.pointsEarned - transaction.pointsRedeemed;

      batch.update(custRef, {
        'totalSpent': FieldValue.increment(transaction.total),
        'points': FieldValue.increment(netPointsDelta),
      });

      if (transaction.pointsRedeemed > 0) {
        final redeemRef =
            _firestore.collection(AppConstants.pointLogsCollection).doc();
        batch.set(redeemRef, {
          'customerId': transaction.customerId,
          'customerName': transaction.customerName ?? '',
          'transactionId': newTxRef.id,
          'type': 'redeem',
          'points': transaction.pointsRedeemed,
          'createdAt': Timestamp.fromDate(now),
        });
      }

      if (transaction.pointsEarned > 0) {
        final earnRef =
            _firestore.collection(AppConstants.pointLogsCollection).doc();
        batch.set(earnRef, {
          'customerId': transaction.customerId,
          'customerName': transaction.customerName ?? '',
          'transactionId': newTxRef.id,
          'type': 'earn',
          'points': transaction.pointsEarned,
          'createdAt': Timestamp.fromDate(now),
        });
      }
    }

    // 6. Customer Receivable / Piutang Pelanggan (PRD Section 5.9)
    double piutangAmount = 0.0;
    if (transaction.status == AppConstants.statusUnpaid) {
      // Jika status belum lunas, sisa tagihan dicatat sebagai piutang
      piutangAmount = (transaction.total - transaction.paidAmount).clamp(0.0, double.infinity);
    } else if (transaction.payments.isNotEmpty) {
      for (final p in transaction.payments) {
        if (p.method.toLowerCase() == 'piutang') {
          piutangAmount += p.amount;
        }
      }
    } else if (transaction.paymentMethod.toLowerCase() == 'piutang') {
      piutangAmount = transaction.total;
    }

    if (piutangAmount > 0) {
      final debtRef =
          _firestore.collection(AppConstants.debtsCollection).doc();
      batch.set(debtRef, {
        'type': 'piutang',
        'partyType': 'customer',
        'partyId': transaction.customerId ?? 'guest',
        'partyName': transaction.customerName ?? 'Pelanggan Umum',
        'referenceNo': transaction.invoiceNumber,
        'amount': piutangAmount,
        'paidAmount': 0.0,
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'status': 'unpaid',
        'notes': 'Piutang Nota ${transaction.invoiceNumber}',
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
    return newTxRef.id;
  }

  /// Cancels / refunds a transaction (Admin only).
  Future<void> cancelTransaction({
    required TransactionModel transaction,
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final txRef = _transactionsRef.doc(transaction.id);

    batch.update(txRef, {
      'status': AppConstants.statusCancelled,
      'cancelReason': reason,
      'cancelledBy': adminName,
      'cancelledAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    List<TransactionItemModel> items = transaction.items;
    if (items.isEmpty) {
      items = await getTransactionItems(transaction.id);
    }

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

  /// Updates an unpaid transaction to completed/lunas once full payment is received.
  Future<void> settleUnpaidTransaction({
    required TransactionModel transaction,
    required double additionalPaidAmount,
    required String paymentMethod,
    required String notes,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final txRef = _transactionsRef.doc(transaction.id);

    final newTotalPaid = transaction.paidAmount + additionalPaidAmount;
    final isFullPaid = newTotalPaid >= transaction.total;

    // 1. Update Transaction status and paid amount
    batch.update(txRef, {
      'status': isFullPaid ? AppConstants.statusCompleted : AppConstants.statusUnpaid,
      'paidAmount': newTotalPaid,
      'changeAmount': (newTotalPaid - transaction.total).clamp(0.0, double.infinity),
      'notes': notes.isNotEmpty
          ? '${transaction.notes.isNotEmpty ? "${transaction.notes} • " : ""}$notes'
          : transaction.notes,
      'updatedAt': Timestamp.fromDate(now),
    });

    // 2. Also settle the corresponding debt in `debts` collection if it exists
    final debtSnap = await _firestore
        .collection(AppConstants.debtsCollection)
        .where('referenceNo', isEqualTo: transaction.invoiceNumber)
        .limit(1)
        .get();

    if (debtSnap.docs.isNotEmpty) {
      final debtDoc = debtSnap.docs.first;
      final currentDebtPaid = (debtDoc.data()['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final debtTotal = (debtDoc.data()['amount'] as num?)?.toDouble() ?? transaction.total;
      final updatedDebtPaid = (currentDebtPaid + additionalPaidAmount).clamp(0.0, debtTotal);
      final debtStatus = updatedDebtPaid >= debtTotal ? 'paid' : 'partial';

      batch.update(debtDoc.reference, {
        'paidAmount': updatedDebtPaid,
        'status': debtStatus,
      });

      // Log payment record in `debt_payments`
      final paymentRef =
          _firestore.collection(AppConstants.debtPaymentsCollection).doc();
      batch.set(paymentRef, {
        'debtId': debtDoc.id,
        'amount': additionalPaidAmount,
        'method': paymentMethod,
        'note': 'Pelunasan Transaksi ${transaction.invoiceNumber}',
        'date': Timestamp.fromDate(now),
        'createdBy': transaction.cashierId,
        'createdByName': transaction.cashierName,
      });
    }

    await batch.commit();
  }

  /// Updates transaction status (e.g. 'completed' / 'unpaid') and automatically
  /// syncs with the corresponding debt record in `debts` (menu pengeluaran & keuangan).
  Future<void> updateTransactionStatus({
    required TransactionModel transaction,
    required String newStatus,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final txRef = _transactionsRef.doc(transaction.id);

    final isLunas = newStatus == AppConstants.statusCompleted;

    batch.update(txRef, {
      'status': newStatus,
      'paidAmount': isLunas ? transaction.total : 0.0,
      'changeAmount': 0.0,
      'updatedAt': Timestamp.fromDate(now),
    });

    final debtSnap = await _firestore
        .collection(AppConstants.debtsCollection)
        .where('referenceNo', isEqualTo: transaction.invoiceNumber)
        .limit(1)
        .get();

    if (debtSnap.docs.isNotEmpty) {
      final debtDoc = debtSnap.docs.first;
      final debtTotal =
          (debtDoc.data()['amount'] as num?)?.toDouble() ?? transaction.total;
      batch.update(debtDoc.reference, {
        'status': isLunas ? 'paid' : 'unpaid',
        'paidAmount': isLunas ? debtTotal : 0.0,
      });

      if (isLunas) {
        final paymentRef =
            _firestore.collection(AppConstants.debtPaymentsCollection).doc();
        batch.set(paymentRef, {
          'debtId': debtDoc.id,
          'amount': debtTotal,
          'method': transaction.paymentMethod,
          'note': 'Pelunasan Transaksi ${transaction.invoiceNumber}',
          'date': Timestamp.fromDate(now),
          'createdBy': transaction.cashierId,
          'createdByName': transaction.cashierName,
        });
      }
    } else if (!isLunas) {
      // Buat pencatatan piutang jika diubah menjadi belum lunas
      final debtRef = _firestore.collection(AppConstants.debtsCollection).doc();
      batch.set(debtRef, {
        'type': 'piutang',
        'partyType': 'customer',
        'partyId': transaction.customerId ?? 'guest',
        'partyName': transaction.customerName ?? 'Pelanggan Umum',
        'referenceNo': transaction.invoiceNumber,
        'amount': transaction.total,
        'paidAmount': 0.0,
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'status': 'unpaid',
        'notes': 'Piutang Nota ${transaction.invoiceNumber}',
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }
}
