import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a product in SiKasirSahaja POS.
///
/// Stored in Firestore under `products/{id}`.
/// Extended in PRD v1.1.0 with [brand], [variants], [expiryDate], and [isArchived].
class ProductModel {
  final String id;
  final String code;
  final String barcode;
  final String name;
  final String brand;
  final List<String> variants;
  final DateTime? expiryDate;
  final bool isArchived;
  final String categoryId;
  final String categoryName;
  final double costPrice;
  final double sellingPrice;
  final int stock;
  final int minimumStock;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.code,
    required this.barcode,
    required this.name,
    this.brand = '',
    this.variants = const [],
    this.expiryDate,
    this.isArchived = false,
    required this.categoryId,
    this.categoryName = '',
    required this.costPrice,
    required this.sellingPrice,
    required this.stock,
    this.minimumStock = 5,
    this.unit = 'pcs',
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if current stock is at or below minimum threshold.
  bool get isLowStock => !isArchived && stock <= minimumStock;

  /// True if product is currently out of stock.
  bool get isOutOfStock => !isArchived && stock <= 0;

  /// True if product has passed its expiry date.
  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expiryDate!.isBefore(today);
  }

  /// True if product expires within the next 30 days.
  bool get isNearExpiry {
    if (expiryDate == null || isExpired) return false;
    final now = DateTime.now();
    return expiryDate!.difference(now).inDays <= 30;
  }

  /// Estimated profit per single unit sold.
  double get profitPerUnit => sellingPrice - costPrice;

  /// Profit margin percentage.
  double get profitMarginPercentage =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0.0;

  /// Creates a [ProductModel] from a Firestore document snapshot.
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductModel.fromMap(data, doc.id);
  }

  /// Creates a [ProductModel] from a Map.
  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    final rawVariants = map['variants'];
    final List<String> parsedVariants = rawVariants is List
        ? rawVariants.map((e) => e.toString()).toList()
        : const [];

    return ProductModel(
      id: id,
      code: map['code'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      variants: parsedVariants,
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
      isArchived: map['isArchived'] as bool? ?? false,
      categoryId: map['categoryId'] as String? ?? '',
      categoryName: map['categoryName'] as String? ?? '',
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      minimumStock: (map['minimumStock'] as num?)?.toInt() ?? 5,
      unit: map['unit'] as String? ?? 'pcs',
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this [ProductModel] to a Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'code': code.trim(),
      'barcode': barcode.trim(),
      'name': name.trim(),
      'brand': brand.trim(),
      'variants': variants,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isArchived': isArchived,
      'categoryId': categoryId,
      'categoryName': categoryName.trim(),
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'stock': stock,
      'minimumStock': minimumStock,
      'unit': unit.trim(),
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a copy of this [ProductModel] with updated fields.
  ProductModel copyWith({
    String? id,
    String? code,
    String? barcode,
    String? name,
    String? brand,
    List<String>? variants,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    bool? isArchived,
    String? categoryId,
    String? categoryName,
    double? costPrice,
    double? sellingPrice,
    int? stock,
    int? minimumStock,
    String? unit,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      code: code ?? this.code,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      variants: variants ?? this.variants,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      isArchived: isArchived ?? this.isArchived,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      minimumStock: minimumStock ?? this.minimumStock,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
