import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single item sold within a transaction.
class TransactionItemModel {
  final String productId;
  final String productName;
  final String productCode;
  final double price;
  final double costPrice;
  final int quantity;
  final String unit;
  final double subtotal;

  const TransactionItemModel({
    required this.productId,
    required this.productName,
    this.productCode = '',
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.unit = 'pcs',
    required this.subtotal,
  });

  /// Factory from Map.
  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productCode: map['productCode'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unit: map['unit'] as String? ?? 'pcs',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this item to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'price': price,
      'costPrice': costPrice,
      'quantity': quantity,
      'unit': unit,
      'subtotal': subtotal,
    };
  }

  TransactionItemModel copyWith({
    String? productId,
    String? productName,
    String? productCode,
    double? price,
    double? costPrice,
    int? quantity,
    String? unit,
    double? subtotal,
  }) {
    return TransactionItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

/// Represents a POS sale transaction in SiKasirSahaja.
///
/// Stored in Firestore under `transactions/{id}`.
class TransactionModel {
  final String id;
  final String invoiceNumber;
  final String cashierId;
  final String cashierName;
  final double subtotal;
  final double discount;
  final double tax;
  final double serviceCharge;
  final double total;
  final double totalCostPrice;
  final String paymentMethod;
  final double paidAmount;
  final double changeAmount;
  final String status; // 'completed', 'cancelled', 'refunded'
  final String notes;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final List<TransactionItemModel> items;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.invoiceNumber,
    required this.cashierId,
    required this.cashierName,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    required this.total,
    this.totalCostPrice = 0.0,
    required this.paymentMethod,
    required this.paidAmount,
    this.changeAmount = 0.0,
    this.status = 'completed',
    this.notes = '',
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
    this.items = const [],
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled' || status == 'refunded';

  /// Total net profit from this transaction.
  double get profit => total - totalCostPrice;

  /// Total count of physical items sold.
  int get totalItemCount =>
      items.fold(0, (total, item) => total + item.quantity);

  /// Factory constructor from Firestore document snapshot.
  factory TransactionModel.fromFirestore(
    DocumentSnapshot doc, [
    List<TransactionItemModel>? itemsList,
  ]) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse embedded items if present in document
    List<TransactionItemModel> parsedItems = itemsList ?? [];
    if (parsedItems.isEmpty && data['items'] is List) {
      parsedItems = (data['items'] as List)
          .map((item) => TransactionItemModel.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return TransactionModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String? ?? '',
      cashierId: data['cashierId'] as String? ?? '',
      cashierName: data['cashierName'] as String? ?? '',
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (data['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      totalCostPrice: (data['totalCostPrice'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (data['changeAmount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'completed',
      notes: data['notes'] as String? ?? '',
      cancelReason: data['cancelReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      items: parsedItems,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this transaction to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'serviceCharge': serviceCharge,
      'total': total,
      'totalCostPrice': totalCostPrice,
      'paymentMethod': paymentMethod,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
      'status': status,
      'notes': notes,
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? invoiceNumber,
    String? cashierId,
    String? cashierName,
    double? subtotal,
    double? discount,
    double? tax,
    double? serviceCharge,
    double? total,
    double? totalCostPrice,
    String? paymentMethod,
    double? paidAmount,
    double? changeAmount,
    String? status,
    String? notes,
    String? cancelReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    List<TransactionItemModel>? items,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      totalCostPrice: totalCostPrice ?? this.totalCostPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
