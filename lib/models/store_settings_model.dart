import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the store and POS settings.
///
/// Stored in Firestore under `store_settings/general`.
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
  final DateTime updatedAt;

  const StoreSettingsModel({
    this.storeName = 'SiKasirSahaja Store',
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
    required this.updatedAt,
  });

  /// Factory constructor from Firestore document snapshot.
  factory StoreSettingsModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return StoreSettingsModel(updatedAt: DateTime.now());
    }
    final data = doc.data() as Map<String, dynamic>;
    return StoreSettingsModel(
      storeName: data['storeName'] as String? ?? 'SiKasirSahaja Store',
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
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
