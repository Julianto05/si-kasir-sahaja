import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee Login/Logout Attendance Log (`attendance_logs` - PRD Section 5.10 & 8.1).
class AttendanceLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final DateTime loginAt;
  final DateTime? logoutAt;
  final String? shiftPlanId;
  final String status; // 'tepat', 'terlambat', 'pulang_awal'

  const AttendanceLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userRole = 'kasir',
    required this.loginAt,
    this.logoutAt,
    this.shiftPlanId,
    this.status = 'tepat',
  });

  String get statusLabel {
    switch (status) {
      case 'terlambat':
        return 'Terlambat';
      case 'pulang_awal':
        return 'Pulang Lebih Awal';
      case 'tepat':
      default:
        return 'Tepat Waktu';
    }
  }

  factory AttendanceLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceLogModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userRole: data['userRole'] as String? ?? 'kasir',
      loginAt: (data['loginAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      logoutAt: (data['logoutAt'] as Timestamp?)?.toDate(),
      shiftPlanId: data['shiftPlanId'] as String?,
      status: data['status'] as String? ?? 'tepat',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'loginAt': Timestamp.fromDate(loginAt),
      'logoutAt': logoutAt != null ? Timestamp.fromDate(logoutAt!) : null,
      'shiftPlanId': shiftPlanId,
      'status': status,
    };
  }
}

/// Employee Work Schedule (`work_schedules` - PRD Section 5.10 & 8.1).
class WorkScheduleModel {
  final String id;
  final String userId;
  final String userName;
  final String dayOfWeek; // 'Senin - Minggu', 'Senin - Jumat', etc.
  final String startTime; // e.g. '08:00'
  final String endTime; // e.g. '17:00'

  const WorkScheduleModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.dayOfWeek = 'Setiap Hari',
    this.startTime = '08:00',
    this.endTime = '17:00',
  });

  String get name => userName;

  factory WorkScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WorkScheduleModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? 'Setiap Hari',
      startTime: data['startTime'] as String? ?? '08:00',
      endTime: data['endTime'] as String? ?? '17:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

/// System Audit Activity Log (`activity_logs` - PRD Section 5.10, 7 & 8.1).
class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String entity;
  final String entityId;
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entity,
    this.entityId = '',
    required this.createdAt,
  });

  String get module => entity;
  String get description => action;

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ActivityLogModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      action: data['action'] as String? ?? '',
      entity: data['entity'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'action': action,
      'entity': entity,
      'entityId': entityId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
