import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Customer / Member in SiKasirSahaja (PRD Section 5.8 & 8.1).
class CustomerModel {
  final String id;
  final String code;
  final String name;
  final String whatsapp;
  final String address;
  final bool isMember;
  final int points;
  final double totalSpent;
  final bool isActive;
  final DateTime createdAt;

  const CustomerModel({
    required this.id,
    required this.code,
    required this.name,
    this.whatsapp = '',
    this.address = '',
    this.isMember = false,
    this.points = 0,
    this.totalSpent = 0.0,
    this.isActive = true,
    required this.createdAt,
  });

  String get phone => whatsapp;

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerModel(
      id: doc.id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      whatsapp: data['whatsapp'] as String? ?? '',
      address: data['address'] as String? ?? '',
      isMember: data['isMember'] as bool? ?? false,
      points: (data['points'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code.trim(),
      'name': name.trim(),
      'whatsapp': whatsapp.trim(),
      'address': address.trim(),
      'isMember': isMember,
      'points': points,
      'totalSpent': totalSpent,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? code,
    String? name,
    String? whatsapp,
    String? address,
    bool? isMember,
    int? points,
    double? totalSpent,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      isMember: isMember ?? this.isMember,
      points: points ?? this.points,
      totalSpent: totalSpent ?? this.totalSpent,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a Loyalty Point Log entry (`earn` or `redeem`) (PRD Section 8.1).
class PointLogModel {
  final String id;
  final String customerId;
  final String customerName;
  final String transactionId;
  final String type; // 'earn' or 'redeem'
  final int points;
  final DateTime createdAt;

  const PointLogModel({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.transactionId,
    required this.type,
    required this.points,
    required this.createdAt,
  });

  factory PointLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PointLogModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      type: data['type'] as String? ?? 'earn',
      points: (data['points'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'transactionId': transactionId,
      'type': type,
      'points': points,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
