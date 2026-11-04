import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single payment method entry in a split/combination payment (PRD Section 5.2 & 8.2).
class PaymentSplitItem {
  final String method;
  final double amount;

  const PaymentSplitItem({required this.method, required this.amount});

  factory PaymentSplitItem.fromMap(Map<String, dynamic> map) {
    return PaymentSplitItem(
      method: map['method'] as String? ?? 'Cash',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'method': method, 'amount': amount};
  }
}

/// Represents a single item sold within a transaction.
class TransactionItemModel {
  final String productId;
  final String productName;
  final String productCode;
  final String variant;
  final double price;
  final double costPrice;
  final int quantity;
  final String unit;
  final double itemDiscount; // Diskon per produk (Rp)
  final double subtotal;

  const TransactionItemModel({
    required this.productId,
    required this.productName,
    this.productCode = '',
    this.variant = '',
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.unit = 'pcs',
    this.itemDiscount = 0.0,
    required this.subtotal,
  });

  /// Factory from Map.
  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productCode: map['productCode'] as String? ?? '',
      variant: map['variant'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unit: map['unit'] as String? ?? 'pcs',
      itemDiscount: (map['itemDiscount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this item to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'variant': variant,
      'price': price,
      'costPrice': costPrice,
      'quantity': quantity,
      'unit': unit,
      'itemDiscount': itemDiscount,
      'subtotal': subtotal,
    };
  }

  TransactionItemModel copyWith({
    String? productId,
    String? productName,
    String? productCode,
    String? variant,
    double? price,
    double? costPrice,
    int? quantity,
    String? unit,
    double? itemDiscount,
    double? subtotal,
  }) {
    return TransactionItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      variant: variant ?? this.variant,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

/// Represents a POS sale transaction in SiKasirSahaja.
///
/// Stored in Firestore under `transactions/{id}`.
/// Extended in PRD v1.1.0 with [customerId], [customerName], [payments],
/// [pointsEarned], [pointsRedeemed], and `'hold'` status.
class TransactionModel {
  final String id;
  final String invoiceNumber;
  final String cashierId;
  final String cashierName;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discount;
  final double tax;
  final double serviceCharge;
  final double total;
  final double totalCostPrice;
  final String paymentMethod;
  final List<PaymentSplitItem> payments;
  final double paidAmount;
  final double changeAmount;
  final int pointsEarned;
  final int pointsRedeemed;
  final String status; // 'completed', 'hold', 'cancelled', 'refunded'
  final String? shiftId;
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
    this.customerId,
    this.customerName,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    this.serviceCharge = 0.0,
    required this.total,
    this.totalCostPrice = 0.0,
    required this.paymentMethod,
    this.payments = const [],
    required this.paidAmount,
    this.changeAmount = 0.0,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.status = 'completed',
    this.shiftId,
    this.notes = '',
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
    this.items = const [],
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isUnpaid => status == 'unpaid';
  bool get isHold => status == 'hold';
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
          .map(
            (item) => TransactionItemModel.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }

    // Parse split payments if present
    List<PaymentSplitItem> parsedPayments = [];
    if (data['payments'] is List) {
      parsedPayments = (data['payments'] as List)
          .whereType<Map>()
          .map((p) => PaymentSplitItem.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    }

    return TransactionModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String? ?? '',
      cashierId: data['cashierId'] as String? ?? '',
      cashierName: data['cashierName'] as String? ?? '',
      customerId: data['customerId'] as String?,
      customerName: data['customerName'] as String?,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (data['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      totalCostPrice: (data['totalCostPrice'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      payments: parsedPayments,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (data['changeAmount'] as num?)?.toDouble() ?? 0.0,
      pointsEarned: (data['pointsEarned'] as num?)?.toInt() ?? 0,
      pointsRedeemed: (data['pointsRedeemed'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'completed',
      shiftId: data['shiftId'] as String?,
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
      'customerId': customerId,
      'customerName': customerName,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'serviceCharge': serviceCharge,
      'total': total,
      'totalCostPrice': totalCostPrice,
      'paymentMethod': paymentMethod,
      'payments': payments.map((e) => e.toMap()).toList(),
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
      'pointsEarned': pointsEarned,
      'pointsRedeemed': pointsRedeemed,
      'status': status,
      'shiftId': shiftId,
      'notes': notes,
      'cancelReason': cancelReason,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
      'items': items.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? invoiceNumber,
    String? cashierId,
    String? cashierName,
    String? customerId,
    String? customerName,
    double? subtotal,
    double? discount,
    double? tax,
    double? serviceCharge,
    double? total,
    double? totalCostPrice,
    String? paymentMethod,
    List<PaymentSplitItem>? payments,
    double? paidAmount,
    double? changeAmount,
    int? pointsEarned,
    int? pointsRedeemed,
    String? status,
    String? shiftId,
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
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      total: total ?? this.total,
      totalCostPrice: totalCostPrice ?? this.totalCostPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      payments: payments ?? this.payments,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      status: status ?? this.status,
      shiftId: shiftId ?? this.shiftId,
      notes: notes ?? this.notes,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
