import 'package:cloud_firestore/cloud_firestore.dart';

double _parseNumToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) {
    return double.tryParse(val.replaceAll(',', '.')) ?? fallback;
  }
  return fallback;
}

int _parseNumToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) {
    return int.tryParse(val) ?? fallback;
  }
  return fallback;
}

DateTime _parseDateTime(dynamic val, [DateTime? fallback]) {
  if (val == null) return fallback ?? DateTime.now();
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) {
    final parsed = DateTime.tryParse(val);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) return DateTime.tryParse(val);
  return null;
}

/// Represents a single payment method entry in a split/combination payment (PRD Section 5.2 & 8.2).
class PaymentSplitItem {
  final String method;
  final double amount;

  const PaymentSplitItem({required this.method, required this.amount});

  factory PaymentSplitItem.fromMap(Map<String, dynamic> map) {
    return PaymentSplitItem(
      method: map['method']?.toString() ?? 'Cash',
      amount: _parseNumToDouble(map['amount']),
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
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      productCode: map['productCode']?.toString() ?? '',
      variant: map['variant']?.toString() ?? '',
      price: _parseNumToDouble(map['price']),
      costPrice: _parseNumToDouble(map['costPrice']),
      quantity: _parseNumToInt(map['quantity'], 1),
      unit: map['unit']?.toString() ?? 'pcs',
      itemDiscount: _parseNumToDouble(map['itemDiscount']),
      subtotal: _parseNumToDouble(map['subtotal']),
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
  final String? customerPhone;
  final String? customerAddress;
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
    this.customerPhone,
    this.customerAddress,
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

    // Parse embedded items safely if present in document
    List<TransactionItemModel> parsedItems = itemsList ?? [];
    if (parsedItems.isEmpty && data['items'] is List) {
      final rawList = data['items'] as List;
      for (final item in rawList) {
        if (item is Map) {
          try {
            parsedItems.add(
              TransactionItemModel.fromMap(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
    }

    // Parse split payments safely if present
    List<PaymentSplitItem> parsedPayments = [];
    if (data['payments'] is List) {
      final rawPayments = data['payments'] as List;
      for (final p in rawPayments) {
        if (p is Map) {
          try {
            parsedPayments.add(
              PaymentSplitItem.fromMap(Map<String, dynamic>.from(p)),
            );
          } catch (_) {}
        }
      }
    }

    return TransactionModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber']?.toString() ?? '',
      cashierId: data['cashierId']?.toString() ?? '',
      cashierName: data['cashierName']?.toString() ?? '',
      customerId: data['customerId']?.toString(),
      customerName: data['customerName']?.toString(),
      customerPhone: data['customerPhone']?.toString(),
      customerAddress: data['customerAddress']?.toString(),
      subtotal: _parseNumToDouble(data['subtotal']),
      discount: _parseNumToDouble(data['discount']),
      tax: _parseNumToDouble(data['tax']),
      serviceCharge: _parseNumToDouble(data['serviceCharge']),
      total: _parseNumToDouble(data['total']),
      totalCostPrice: _parseNumToDouble(data['totalCostPrice']),
      paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
      payments: parsedPayments,
      paidAmount: _parseNumToDouble(data['paidAmount']),
      changeAmount: _parseNumToDouble(data['changeAmount']),
      pointsEarned: _parseNumToInt(data['pointsEarned']),
      pointsRedeemed: _parseNumToInt(data['pointsRedeemed']),
      status: data['status']?.toString() ?? 'completed',
      shiftId: data['shiftId']?.toString(),
      notes: data['notes']?.toString() ?? '',
      cancelReason: data['cancelReason']?.toString(),
      cancelledBy: data['cancelledBy']?.toString(),
      cancelledAt: _parseNullableDateTime(data['cancelledAt']),
      items: parsedItems,
      createdAt: _parseDateTime(data['createdAt']),
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
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
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
    String? customerPhone,
    String? customerAddress,
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
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
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
