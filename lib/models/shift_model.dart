import 'package:cloud_firestore/cloud_firestore.dart';

import 'transaction_model.dart';

/// Helper functions for safe parsing across different Firestore data versions.
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

/// Represents a manual petty cash entry (Kas Masuk / Kas Keluar) during an active shift.
class ShiftCashEntry {
  final String id;
  final String type; // 'in' or 'out'
  final double amount;
  final String reason;
  final DateTime createdAt;

  const ShiftCashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory ShiftCashEntry.fromMap(Map<String, dynamic> map) {
    return ShiftCashEntry(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'out',
      amount: _parseNumToDouble(map['amount']),
      reason: map['reason']?.toString() ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'reason': reason.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Represents a Cashier Work Shift (Buka Shift & Tutup Shift / Closing).
///
/// Extended in PRD v1.1.0 Section 5.3 & 8.2 with [cashIn] and [cashOut] manual petty cash entries.
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
  final double cashDifference; // Selisih = physicalCash - expectedCash
  final double physicalNonCash; // Total fisik bukti transfer / slip EDC hasil hitungan kasir
  final int nonCashReceiptCount; // Jumlah lembar bukti transfer / slip EDC
  final double nonCashDifference; // Selisih = physicalNonCash - nonCashSales
  final Map<String, int> denominations; // Rincian pecahan uang
  final List<ShiftCashEntry> cashIn; // Catatan kas kecil masuk manual
  final List<ShiftCashEntry> cashOut; // Catatan kas kecil keluar manual
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
    this.physicalNonCash = 0.0,
    this.nonCashReceiptCount = 0,
    this.nonCashDifference = 0.0,
    this.denominations = const {},
    this.cashIn = const [],
    this.cashOut = const [],
    this.notes = '',
    this.status = 'open',
  });

  bool get isOpen => status == 'open' && closedAt == null;
  bool get isClosed => status == 'closed' || closedAt != null;

  double get totalCashIn =>
      cashIn.fold(0.0, (acc, entry) => acc + entry.amount);

  double get totalCashOut =>
      cashOut.fold(0.0, (acc, entry) => acc + entry.amount);

  /// Expected physical cash in drawer = startingCash + cashSales + manual cashIn - manual cashOut.
  double get expectedCash =>
      startingCash + cashSales + totalCashIn - totalCashOut;

  /// Total physical setoran kasir = fisik tunai + fisik non-tunai (bukti transfer/EDC)
  double get totalPhysicalIncome => physicalCash + physicalNonCash;

  /// Total yang seharusnya diterima = kas laci + penjualan non-tunai
  double get totalExpectedIncome => expectedCash + nonCashSales;

  /// Total selisih fisik kasir (tunai + non-tunai)
  double get totalIncomeDifference =>
      cashDifference + nonCashDifference;

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, int> parseDenominations(dynamic raw) {
      if (raw is Map) {
        final result = <String, int>{};
        raw.forEach((k, v) {
          result[k.toString()] = _parseNumToInt(v);
        });
        return result;
      }
      return {};
    }

    List<ShiftCashEntry> parseCashList(dynamic raw) {
      if (raw is List) {
        final list = <ShiftCashEntry>[];
        for (final item in raw) {
          if (item is Map) {
            try {
              list.add(ShiftCashEntry.fromMap(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
        }
        return list;
      }
      return const [];
    }

    return ShiftModel(
      id: doc.id,
      cashierId: data['cashierId']?.toString() ?? '',
      cashierName: data['cashierName']?.toString() ?? '',
      openedAt: _parseDateTime(data['openedAt']),
      closedAt: _parseNullableDateTime(data['closedAt']),
      startingCash: _parseNumToDouble(data['startingCash']),
      cashSales: _parseNumToDouble(data['cashSales']),
      nonCashSales: _parseNumToDouble(data['nonCashSales']),
      totalSales: _parseNumToDouble(data['totalSales']),
      transactionCount: _parseNumToInt(data['transactionCount']),
      physicalCash: _parseNumToDouble(data['physicalCash']),
      cashDifference: _parseNumToDouble(data['cashDifference']),
      physicalNonCash: _parseNumToDouble(data['physicalNonCash']),
      nonCashReceiptCount: _parseNumToInt(data['nonCashReceiptCount']),
      nonCashDifference: _parseNumToDouble(data['nonCashDifference']),
      denominations: parseDenominations(data['denominations']),
      cashIn: parseCashList(data['cashIn']),
      cashOut: parseCashList(data['cashOut']),
      notes: data['notes']?.toString() ?? '',
      status: data['status']?.toString() ?? 'open',
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
      'physicalNonCash': physicalNonCash,
      'nonCashReceiptCount': nonCashReceiptCount,
      'nonCashDifference': nonCashDifference,
      'denominations': denominations,
      'cashIn': cashIn.map((e) => e.toMap()).toList(),
      'cashOut': cashOut.map((e) => e.toMap()).toList(),
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
    double? physicalNonCash,
    int? nonCashReceiptCount,
    double? nonCashDifference,
    Map<String, int>? denominations,
    List<ShiftCashEntry>? cashIn,
    List<ShiftCashEntry>? cashOut,
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
      physicalNonCash: physicalNonCash ?? this.physicalNonCash,
      nonCashReceiptCount: nonCashReceiptCount ?? this.nonCashReceiptCount,
      nonCashDifference: nonCashDifference ?? this.nonCashDifference,
      denominations: denominations ?? this.denominations,
      cashIn: cashIn ?? this.cashIn,
      cashOut: cashOut ?? this.cashOut,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

/// Rincian penjualan dan arus kas aktual selama sesi shift berjalan.
class ShiftSalesBreakdown {
  final double
  cashSales; // Total uang kas nyata yang diterima laci kasir (setelah dipotong kembalian)
  final double nonCashSales; // Total pembayaran digital (QRIS, Transfer, EDC)
  final double unpaidSales; // Total penjualan belum lunas (piutang / bon)
  final double totalSales; // Total seluruh omset penjualan
  final int transactionCount; // Total nota transaksi non-batal

  const ShiftSalesBreakdown({
    required this.cashSales,
    required this.nonCashSales,
    required this.unpaidSales,
    required this.totalSales,
    required this.transactionCount,
  });

  factory ShiftSalesBreakdown.compute(List<TransactionModel> transactions) {
    double cash = 0.0;
    double nonCash = 0.0;
    double unpaid = 0.0;
    int count = 0;

    for (final tx in transactions) {
      if (tx.isCancelled) continue;
      count++;

      if (tx.isUnpaid) {
        // Transaksi belum lunas: hitung apakah ada uang muka (DP / paidAmount)
        if (tx.paidAmount > 0) {
          if (tx.payments.isNotEmpty) {
            for (final p in tx.payments) {
              final m = p.method.toLowerCase();
              if (m == 'cash' || m == 'tunai') {
                cash += p.amount;
              } else {
                nonCash += p.amount;
              }
            }
          } else {
            final m = tx.paymentMethod.toLowerCase();
            if (m == 'cash' || m == 'tunai') {
              cash += tx.paidAmount;
            } else {
              nonCash += tx.paidAmount;
            }
          }
        }
        final sisaBelumLunas = tx.total - tx.paidAmount;
        if (sisaBelumLunas > 0) {
          unpaid += sisaBelumLunas;
        }
      } else {
        // Transaksi lunas
        if (tx.payments.isNotEmpty) {
          double txCash = 0.0;
          for (final p in tx.payments) {
            final m = p.method.toLowerCase();
            if (m == 'cash' || m == 'tunai') {
              txCash += p.amount;
            } else {
              nonCash += p.amount;
            }
          }
          // Kurangi uang kembalian yang telah dikembalikan ke pelanggan
          final netCash = txCash - tx.changeAmount;
          cash += netCash > 0 ? netCash : 0.0;
        } else {
          final m = tx.paymentMethod.toLowerCase();
          if (m == 'cash' || m == 'tunai') {
            cash += tx.total;
          } else {
            nonCash += tx.total;
          }
        }
      }
    }

    final total = cash + nonCash + unpaid;
    return ShiftSalesBreakdown(
      cashSales: cash,
      nonCashSales: nonCash,
      unpaidSales: unpaid,
      totalSales: total,
      transactionCount: count,
    );
  }
}
