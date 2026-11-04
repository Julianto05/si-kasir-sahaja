import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Discount / Promo campaign in SiKasirSahaja (PRD Section 5.11 & 8.1).
///
/// Types:
/// - `'produk'`: Diskon pada produk tertentu
/// - `'transaksi'`: Diskon total belanja (dengan minimal pembelian)
/// - `'member'`: Diskon khusus pelanggan member
/// - `'bogo'`: Promo Beli 1 Gratis 1 / Bertingkat
/// - `'kupon'`: Kupon potongan dengan kode voucher
class DiscountModel {
  final String id;
  final String name;
  final String code;
  final String type; // 'produk', 'transaksi', 'member', 'bogo', 'kupon'
  final double value; // Persentase (0-100) atau Nominal (Rp)
  final bool isPercentage;
  final double minPurchase;
  final List<String> productIds;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  const DiscountModel({
    required this.id,
    required this.name,
    this.code = '',
    required this.type,
    required this.value,
    this.isPercentage = true,
    this.minPurchase = 0.0,
    this.productIds = const [],
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return !now.isBefore(start) && !now.isAfter(end);
  }

  String get typeLabel {
    switch (type) {
      case 'produk':
        return 'Diskon Produk';
      case 'transaksi':
        return 'Diskon Transaksi';
      case 'member':
        return 'Khusus Member';
      case 'bogo':
        return 'Buy 1 Get 1';
      case 'kupon':
        return 'Kupon Voucher';
      default:
        return type;
    }
  }

  /// Calculates discount amount for a given subtotal.
  double calculateDiscount(double subtotal, {bool isCustomerMember = false}) {
    if (!isValidNow) return 0.0;
    if (subtotal < minPurchase) return 0.0;
    if (type == 'member' && !isCustomerMember) return 0.0;

    if (isPercentage) {
      return (subtotal * (value / 100.0)).clamp(0.0, subtotal);
    } else {
      return value.clamp(0.0, subtotal);
    }
  }

  factory DiscountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawProducts = data['productIds'];
    final List<String> parsedProducts = rawProducts is List
        ? rawProducts.map((e) => e.toString()).toList()
        : const [];

    return DiscountModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      type: data['type'] as String? ?? 'transaksi',
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      isPercentage: data['isPercentage'] as bool? ?? true,
      minPurchase: (data['minPurchase'] as num?)?.toDouble() ?? 0.0,
      productIds: parsedProducts,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate:
          (data['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'type': type,
      'value': value,
      'isPercentage': isPercentage,
      'minPurchase': minPurchase,
      'productIds': productIds,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  DiscountModel copyWith({
    String? id,
    String? name,
    String? code,
    String? type,
    double? value,
    bool? isPercentage,
    double? minPurchase,
    List<String>? productIds,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DiscountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      value: value ?? this.value,
      isPercentage: isPercentage ?? this.isPercentage,
      minPurchase: minPurchase ?? this.minPurchase,
      productIds: productIds ?? this.productIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
