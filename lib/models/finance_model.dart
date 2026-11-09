import 'package:cloud_firestore/cloud_firestore.dart';

/// Operational Expense entry (`expenses` collection - PRD Section 5.9 & 8.1).
class ExpenseModel {
  final String id;
  final String
  category; // 'operasional', 'listrik_air', 'transportasi', 'gaji', 'lainnya'
  final double amount;
  final String note;
  final DateTime date;
  final String createdBy;
  final String createdByName;

  const ExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    this.note = '',
    required this.date,
    required this.createdBy,
    this.createdByName = '',
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExpenseModel(
      id: doc.id,
      category: data['category'] as String? ?? 'operasional',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'note': note.trim(),
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }
}

/// Capital Injection entry (`capital_entries` collection - PRD Section 5.9 & 8.1).
class CapitalEntryModel {
  final String id;
  final double amount;
  final String note;
  final DateTime date;
  final String createdBy;
  final String createdByName;

  const CapitalEntryModel({
    required this.id,
    required this.amount,
    this.note = '',
    required this.date,
    required this.createdBy,
    this.createdByName = '',
  });

  factory CapitalEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CapitalEntryModel(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'note': note.trim(),
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }
}

/// Payable (Utang Supplier) or Receivable (Piutang Pelanggan) record (`debts` - PRD Section 5.9 & 8.1).
class DebtModel {
  final String id;
  final String
  type; // 'utang' (Payable to Supplier) or 'piutang' (Receivable from Customer)
  final String partyType; // 'supplier' or 'customer'
  final String partyId;
  final String partyName;
  final String phone;
  final String address;
  final String referenceNo; // Purchase No or Invoice No
  final double amount;
  final double paidAmount;
  final DateTime? dueDate;
  final String status; // 'unpaid', 'partial', 'paid'
  final String notes;
  final DateTime createdAt;

  const DebtModel({
    required this.id,
    required this.type,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    this.phone = '',
    this.address = '',
    this.referenceNo = '',
    required this.amount,
    this.paidAmount = 0.0,
    this.dueDate,
    this.status = 'unpaid',
    this.notes = '',
    required this.createdAt,
  });

  double get remainingAmount =>
      (amount - paidAmount).clamp(0.0, double.infinity);
  bool get isPaid => status == 'paid' || remainingAmount <= 0;

  factory DebtModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DebtModel(
      id: doc.id,
      type: data['type'] as String? ?? 'utang',
      partyType: data['partyType'] as String? ?? 'supplier',
      partyId: data['partyId'] as String? ?? '',
      partyName: data['partyName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      referenceNo: data['referenceNo'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'unpaid',
      notes: data['notes'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'partyType': partyType,
      'partyId': partyId,
      'partyName': partyName,
      'phone': phone.trim(),
      'address': address.trim(),
      'referenceNo': referenceNo,
      'amount': amount,
      'paidAmount': paidAmount,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'status': status,
      'notes': notes.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Installment / Payment record for a Debt (`debt_payments` - PRD Section 8.1).
class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final String method;
  final String note;
  final DateTime date;
  final String createdBy;
  final String createdByName;

  const DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    this.method = 'Cash',
    this.note = '',
    required this.date,
    required this.createdBy,
    this.createdByName = '',
  });

  factory DebtPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DebtPaymentModel(
      id: doc.id,
      debtId: data['debtId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      method: data['method'] as String? ?? 'Cash',
      note: data['note'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'debtId': debtId,
      'amount': amount,
      'method': method,
      'note': note.trim(),
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }
}
