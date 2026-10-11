import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Cashier Work Shift (Buka Shift & Tutup Shift / Closing).
class ShiftModel {
  final String id;
  final String cashierId;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double startingCash; // Modal awal di laci
  final double cashSales; // Total penjualan tunai sistem
  final double nonCashSales; // Total penjualan non-tunai (QRIS, Transfer, EDC)
  final double totalSales; // Total penjualan
  final int transactionCount; // Jumlah transaksi berhasil
  final double physicalCash; // Total fisik uang hasil hitungan kasir
  final double cashDifference; // Selisih = physicalCash - (startingCash + cashSales)
  final Map<String, int> denominations; // Rincian pecahan uang (e.g. "100000": 10, "50000": 5)
  final String notes; // Catatan kasir saat closing
  final String status; // 'open' or 'closed'

  const ShiftModel({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    this.startingCash = 0.0,
    this.cashSales = 0.0,
    this.nonCashSales = 0.0,
    this.totalSales = 0.0,
    this.transactionCount = 0,
    this.physicalCash = 0.0,
    this.cashDifference = 0.0,
    this.denominations = const {},
    this.notes = '',
    this.status = 'open',
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  double get expectedCash => startingCash + cashSales;

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, int> parseDenominations(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    return ShiftModel(
      id: doc.id,
      cashierId: data['cashierId'] as String? ?? '',
      cashierName: data['cashierName'] as String? ?? '',
      openedAt: (data['openedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      startingCash: (data['startingCash'] as num?)?.toDouble() ?? 0.0,
      cashSales: (data['cashSales'] as num?)?.toDouble() ?? 0.0,
      nonCashSales: (data['nonCashSales'] as num?)?.toDouble() ?? 0.0,
      totalSales: (data['totalSales'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (data['transactionCount'] as num?)?.toInt() ?? 0,
      physicalCash: (data['physicalCash'] as num?)?.toDouble() ?? 0.0,
      cashDifference: (data['cashDifference'] as num?)?.toDouble() ?? 0.0,
      denominations: parseDenominations(data['denominations']),
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cashierId': cashierId,
      'cashierName': cashierName,
      'openedAt': Timestamp.fromDate(openedAt),
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'startingCash': startingCash,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'totalSales': totalSales,
      'transactionCount': transactionCount,
      'physicalCash': physicalCash,
      'cashDifference': cashDifference,
      'denominations': denominations,
      'notes': notes,
      'status': status,
    };
  }

  ShiftModel copyWith({
    String? id,
    String? cashierId,
    String? cashierName,
    DateTime? openedAt,
    DateTime? closedAt,
    double? startingCash,
    double? cashSales,
    double? nonCashSales,
    double? totalSales,
    int? transactionCount,
    double? physicalCash,
    double? cashDifference,
    Map<String, int>? denominations,
    String? notes,
    String? status,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      startingCash: startingCash ?? this.startingCash,
      cashSales: cashSales ?? this.cashSales,
      nonCashSales: nonCashSales ?? this.nonCashSales,
      totalSales: totalSales ?? this.totalSales,
      transactionCount: transactionCount ?? this.transactionCount,
      physicalCash: physicalCash ?? this.physicalCash,
      cashDifference: cashDifference ?? this.cashDifference,
      denominations: denominations ?? this.denominations,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
