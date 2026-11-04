import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the store and POS settings.
///
/// Stored in Firestore under `store_settings/general`.
/// Extended in PRD v1.1.0 Section 5.6 & 8.2 with active payment methods,
/// loyalty points rules, member discount, and barcode settings.
class StoreSettingsModel {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String storeEmail;
  final String? storeLogoUrl;
  final double taxPercentage;
  final double serviceChargePercentage;
  final String receiptFooter;
  final String invoicePrefix;
  final bool enableTax;
  final bool enableServiceCharge;
  final List<String> activePaymentMethods;
  final bool enableLoyaltyPoints;
  final double pointsPerAmount; // Belanja kelipatan Rp X mendapat 1 poin
  final double pointRedeemValue; // 1 poin bernilai potongan Rp Y
  final double memberDiscountPercentage; // Diskon otomatis khusus member (%)
  final bool enableBarcodeScanner;
  final DateTime updatedAt;

  const StoreSettingsModel({
    this.storeName = 'Toko Pusaka Rinjani',
    this.storeAddress = 'Jl. Raya Utama No. 123',
    this.storePhone = '0812-3456-7890',
    this.storeEmail = 'store@sikasirsahaja.com',
    this.storeLogoUrl,
    this.taxPercentage = 0.0,
    this.serviceChargePercentage = 0.0,
    this.receiptFooter = 'Terima kasih atas kunjungan Anda!',
    this.invoicePrefix = 'TRX',
    this.enableTax = false,
    this.enableServiceCharge = false,
    this.activePaymentMethods = const [
      'Cash',
      'QRIS',
      'Transfer',
      'Debit',
      'Kredit',
    ],
    this.enableLoyaltyPoints = true,
    this.pointsPerAmount = 10000.0,
    this.pointRedeemValue = 100.0,
    this.memberDiscountPercentage = 2.0,
    this.enableBarcodeScanner = true,
    required this.updatedAt,
  });

  /// Factory constructor from Firestore document snapshot.
  factory StoreSettingsModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return StoreSettingsModel(updatedAt: DateTime.now());
    }
    final data = doc.data() as Map<String, dynamic>;

    final rawMethods = data['activePaymentMethods'];
    final List<String> methods = rawMethods is List && rawMethods.isNotEmpty
        ? rawMethods.map((e) => e.toString()).toList()
        : const ['Cash', 'QRIS', 'Transfer', 'Debit', 'Kredit'];

    return StoreSettingsModel(
      storeName: data['storeName'] as String? ?? 'Toko Pusaka Rinjani',
      storeAddress: data['storeAddress'] as String? ?? '',
      storePhone: data['storePhone'] as String? ?? '',
      storeEmail: data['storeEmail'] as String? ?? '',
      storeLogoUrl: data['storeLogoUrl'] as String?,
      taxPercentage: (data['taxPercentage'] as num?)?.toDouble() ?? 0.0,
      serviceChargePercentage:
          (data['serviceChargePercentage'] as num?)?.toDouble() ?? 0.0,
      receiptFooter: data['receiptFooter'] as String? ??
          'Terima kasih atas kunjungan Anda!',
      invoicePrefix: data['invoicePrefix'] as String? ?? 'TRX',
      enableTax: data['enableTax'] as bool? ?? false,
      enableServiceCharge: data['enableServiceCharge'] as bool? ?? false,
      activePaymentMethods: methods,
      enableLoyaltyPoints: data['enableLoyaltyPoints'] as bool? ?? true,
      pointsPerAmount: (data['pointsPerAmount'] as num?)?.toDouble() ?? 10000.0,
      pointRedeemValue: (data['pointRedeemValue'] as num?)?.toDouble() ?? 100.0,
      memberDiscountPercentage:
          (data['memberDiscountPercentage'] as num?)?.toDouble() ?? 2.0,
      enableBarcodeScanner: data['enableBarcodeScanner'] as bool? ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this settings model to a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName.trim(),
      'storeAddress': storeAddress.trim(),
      'storePhone': storePhone.trim(),
      'storeEmail': storeEmail.trim(),
      'storeLogoUrl': storeLogoUrl,
      'taxPercentage': taxPercentage,
      'serviceChargePercentage': serviceChargePercentage,
      'receiptFooter': receiptFooter.trim(),
      'invoicePrefix': invoicePrefix.trim(),
      'enableTax': enableTax,
      'enableServiceCharge': enableServiceCharge,
      'activePaymentMethods': activePaymentMethods,
      'enableLoyaltyPoints': enableLoyaltyPoints,
      'pointsPerAmount': pointsPerAmount,
      'pointRedeemValue': pointRedeemValue,
      'memberDiscountPercentage': memberDiscountPercentage,
      'enableBarcodeScanner': enableBarcodeScanner,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  StoreSettingsModel copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? storeEmail,
    String? storeLogoUrl,
    double? taxPercentage,
    double? serviceChargePercentage,
    String? receiptFooter,
    String? invoicePrefix,
    bool? enableTax,
    bool? enableServiceCharge,
    List<String>? activePaymentMethods,
    bool? enableLoyaltyPoints,
    double? pointsPerAmount,
    double? pointRedeemValue,
    double? memberDiscountPercentage,
    bool? enableBarcodeScanner,
    DateTime? updatedAt,
  }) {
    return StoreSettingsModel(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      storeEmail: storeEmail ?? this.storeEmail,
      storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      serviceChargePercentage:
          serviceChargePercentage ?? this.serviceChargePercentage,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      enableTax: enableTax ?? this.enableTax,
      enableServiceCharge: enableServiceCharge ?? this.enableServiceCharge,
      activePaymentMethods: activePaymentMethods ?? this.activePaymentMethods,
      enableLoyaltyPoints: enableLoyaltyPoints ?? this.enableLoyaltyPoints,
      pointsPerAmount: pointsPerAmount ?? this.pointsPerAmount,
      pointRedeemValue: pointRedeemValue ?? this.pointRedeemValue,
      memberDiscountPercentage:
          memberDiscountPercentage ?? this.memberDiscountPercentage,
      enableBarcodeScanner: enableBarcodeScanner ?? this.enableBarcodeScanner,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
