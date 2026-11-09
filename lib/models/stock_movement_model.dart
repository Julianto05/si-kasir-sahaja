import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an inventory stock change record in SiKasirSahaja.
///
/// Types (PRD v1.1.0 Section 8.2):
/// - `'in'`: Stock received / Restock manual
/// - `'purchase_in'`: Stock received from supplier purchase
/// - `'purchase_return'`: Stock returned to supplier
/// - `'out'`: Stock written off
/// - `'damaged'`: Barang rusak
/// - `'expired'`: Barang kedaluwarsa
/// - `'sale'`: Stock automatically deducted from POS transaction
/// - `'adjustment'`: Stock manual adjustment / stock opname
/// - `'refund'`: Stock returned from cancelled transaction
class StockMovementModel {
  final String id;
  final String productId;
  final String productName;
  final String productCode;
  final String type;
  final int quantity;
  final int stockBefore;
  final int stockAfter;
  final String notes;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productCode = '',
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.notes = '',
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  /// Factory from Firestore DocumentSnapshot.
  factory StockMovementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StockMovementModel(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      productCode: data['productCode'] as String? ?? '',
      type: data['type'] as String? ?? 'in',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      stockBefore: (data['stockBefore'] as num?)?.toInt() ?? 0,
      stockAfter: (data['stockAfter'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this movement to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'type': type,
      'quantity': quantity,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'notes': notes,
      'userId': userId,
      'userName': userName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// True if this movement increases stock.
  bool get isAddition => stockAfter >= stockBefore;

  /// User friendly label in Indonesian.
  String get typeLabel {
    switch (type) {
      case 'in':
        return 'Stok Masuk';
      case 'purchase_in':
        return 'Pembelian Supplier';
      case 'purchase_return':
        return 'Retur Pembelian';
      case 'sale':
        return 'Penjualan POS';
      case 'adjustment':
        return 'Penyesuaian Opname';
      case 'refund':
        return 'Pengembalian / Refund';
      case 'damaged':
        return 'Barang Rusak';
      case 'expired':
        return 'Barang Kedaluwarsa';
      case 'out':
        return 'Stok Keluar';
      default:
        return type;
    }
  }
}
