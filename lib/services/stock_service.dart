import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/stock_movement_model.dart';

/// Service layer for manual stock restock, adjustments, damaged/expired write-offs, and movement audit trails (PRD Section 5.4).
class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection(AppConstants.productsCollection);

  CollectionReference<Map<String, dynamic>> get _movementsRef =>
      _firestore.collection(AppConstants.stockMovementsCollection);

  /// Streams inventory movements ordered by timestamp descending.
  Stream<List<StockMovementModel>> streamMovements({
    String? productId,
    String? type,
  }) {
    return _movementsRef.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => StockMovementModel.fromFirestore(doc))
          .where((m) {
            if (productId != null &&
                productId.isNotEmpty &&
                productId != 'all' &&
                m.productId != productId) {
              return false;
            }
            if (type != null &&
                type.isNotEmpty &&
                type != 'all' &&
                m.type != type) {
              return false;
            }
            return true;
          })
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Adds stock into inventory (Restock from supplier).
  Future<void> addStockIn({
    required String productId,
    required String productName,
    required String productCode,
    required int currentStock,
    required int addQuantity,
    required String notes,
    required String userId,
    required String userName,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final newStock = currentStock + addQuantity;

    // 1. Update product stock
    final productRef = _productsRef.doc(productId);
    batch.update(productRef, {
      'stock': newStock,
      'updatedAt': Timestamp.fromDate(now),
    });

    // 2. Log stock movement
    final movementRef = _movementsRef.doc();
    final movement = StockMovementModel(
      id: movementRef.id,
      productId: productId,
      productName: productName,
      productCode: productCode,
      type: AppConstants.stockIn,
      quantity: addQuantity,
      stockBefore: currentStock,
      stockAfter: newStock,
      notes: notes.trim().isNotEmpty ? notes.trim() : 'Stok masuk manual',
      userId: userId,
      userName: userName,
      createdAt: now,
    );
    batch.set(movementRef, movement.toMap());

    await batch.commit();
  }

  /// Adjusts stock count manually (Stock Opname, damaged, expired, correction).
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required String productCode,
    required int currentStock,
    required int newStock,
    required String reason,
    required String userId,
    required String userName,
    String movementType = AppConstants.stockAdjustment,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final difference = newStock - currentStock;

    // 1. Update product stock
    final productRef = _productsRef.doc(productId);
    batch.update(productRef, {
      'stock': newStock,
      'updatedAt': Timestamp.fromDate(now),
    });

    // 2. Log stock movement
    final movementRef = _movementsRef.doc();
    final movement = StockMovementModel(
      id: movementRef.id,
      productId: productId,
      productName: productName,
      productCode: productCode,
      type: movementType,
      quantity: difference.abs(),
      stockBefore: currentStock,
      stockAfter: newStock,
      notes: reason.trim(),
      userId: userId,
      userName: userName,
      createdAt: now,
    );
    batch.set(movementRef, movement.toMap());

    // 3. Log activity audit
    final logRef = _firestore
        .collection(AppConstants.activityLogsCollection)
        .doc();
    batch.set(logRef, {
      'userId': userId,
      'userName': userName,
      'action':
          'Ubah Stok $productName ($currentStock -> $newStock) [${movement.typeLabel}]',
      'entity': 'products',
      'entityId': productId,
      'createdAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }
}
