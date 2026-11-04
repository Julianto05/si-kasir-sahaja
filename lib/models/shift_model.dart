import 'package:cloud_firestore/cloud_firestore.dart';

import 'transaction_model.dart';

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
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'out',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    this.denominations = const {},
    this.cashIn = const [],
    this.cashOut = const [],
    this.notes = '',
    this.status = 'open',
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  double get totalCashIn =>
      cashIn.fold(0.0, (acc, entry) => acc + entry.amount);

  double get totalCashOut =>
      cashOut.fold(0.0, (acc, entry) => acc + entry.amount);

  /// Expected physical cash in drawer = startingCash + cashSales + manual cashIn - manual cashOut.
  double get expectedCash =>
      startingCash + cashSales + totalCashIn - totalCashOut;

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    Map<String, int> parseDenominations(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    List<ShiftCashEntry> parseCashList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => ShiftCashEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
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
      cashIn: parseCashList(data['cashIn']),
      cashOut: parseCashList(data['cashOut']),
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
  final double cashSales; // Total uang kas nyata yang diterima laci kasir (setelah dipotong kembalian)
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
              if (p.method.toLowerCase() == 'cash') {
                cash += p.amount;
              } else {
                nonCash += p.amount;
              }
            }
          } else if (tx.paymentMethod.toLowerCase() == 'cash') {
            cash += tx.paidAmount;
          } else {
            nonCash += tx.paidAmount;
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
            if (p.method.toLowerCase() == 'cash') {
              txCash += p.amount;
            } else {
              nonCash += p.amount;
            }
          }
          // Kurangi uang kembalian yang telah dikembalikan ke pelanggan
          final netCash = txCash - tx.changeAmount;
          cash += netCash > 0 ? netCash : 0.0;
        } else {
          if (tx.paymentMethod.toLowerCase() == 'cash') {
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
