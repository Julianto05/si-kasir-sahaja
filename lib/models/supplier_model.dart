import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Supplier in SiKasirSahaja (PRD Section 5.7 & 8.1).
class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final bool isActive;
  final DateTime createdAt;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.isActive = true,
    required this.createdAt,
  });

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupplierModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a single item bought in a Supplier Purchase Order.
class PurchaseItemModel {
  final String productId;
  final String productName;
  final String productCode;
  final int qty;
  final double buyPrice;
  final String unit;

  const PurchaseItemModel({
    required this.productId,
    required this.productName,
    this.productCode = '',
    required this.qty,
    required this.buyPrice,
    this.unit = 'pcs',
  });

  double get subtotal => qty * buyPrice;

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productCode: map['productCode'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'pcs',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'qty': qty,
      'buyPrice': buyPrice,
      'unit': unit,
    };
  }
}

/// Represents a Purchase Order / Goods Receipt from a Supplier (PRD Section 5.7 & 8.1).
class PurchaseModel {
  final String id;
  final String purchaseNo;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final List<PurchaseItemModel> items;
  final double total;
  final double paidAmount;
  final String paymentStatus; // 'paid' (Lunas), 'partial' (Sebagian), 'unpaid' (Belum Dibayar)
  final String notes;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  const PurchaseModel({
    required this.id,
    required this.purchaseNo,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    this.items = const [],
    required this.total,
    required this.paidAmount,
    required this.paymentStatus,
    this.notes = '',
    required this.createdBy,
    this.createdByName = '',
    required this.createdAt,
  });

  double get remainingDebt => (total - paidAmount).clamp(0.0, double.infinity);

  bool get isPaid => paymentStatus == 'paid' || remainingDebt <= 0;

  String get paymentStatusLabel {
    if (isPaid) return 'Lunas';
    if (paidAmount > 0) return 'Dibayar Sebagian';
    return 'Belum Dibayar (Utang)';
  }

  factory PurchaseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawItems = data['items'];
    final List<PurchaseItemModel> parsedItems = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => PurchaseItemModel.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : const [];

    return PurchaseModel(
      id: doc.id,
      purchaseNo: data['purchaseNo'] as String? ?? '',
      supplierId: data['supplierId'] as String? ?? '',
      supplierName: data['supplierName'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: parsedItems,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: data['paymentStatus'] as String? ?? 'paid',
      notes: data['notes'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseNo': purchaseNo,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'date': Timestamp.fromDate(date),
      'items': items.map((e) => e.toMap()).toList(),
      'total': total,
      'paidAmount': paidAmount,
      'paymentStatus': paymentStatus,
      'notes': notes.trim(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

