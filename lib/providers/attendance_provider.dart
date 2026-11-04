import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';

/// Provider for managing Employee Attendance, Work Schedules, and Activity Audit Logs (`attendance_logs`, `work_schedules`, `activity_logs` - PRD Section 4 & 5.10).
class AttendanceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<AttendanceLogModel> _attendanceLogs = [];
  List<WorkScheduleModel> _schedules = [];
  List<ActivityLogModel> _activityLogs = [];

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _attendanceSub;
  StreamSubscription<QuerySnapshot>? _scheduleSub;
  StreamSubscription<QuerySnapshot>? _activitySub;

  AttendanceProvider() {
    _initStreams();
  }

  List<AttendanceLogModel> get attendanceLogs => _attendanceLogs;
  List<WorkScheduleModel> get schedules => _schedules;
  List<WorkScheduleModel> get workSchedules => _schedules;
  List<ActivityLogModel> get activityLogs => _activityLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    _attendanceSub = _firestore
        .collection(AppConstants.attendanceLogsCollection)
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((doc) => AttendanceLogModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.loginAt.compareTo(a.loginAt));
      _attendanceLogs = list;
      _isLoading = false;
      notifyListeners();
    });

    _scheduleSub = _firestore
        .collection(AppConstants.workSchedulesCollection)
        .snapshots()
        .listen((snap) {
      final list =
          snap.docs.map((doc) => WorkScheduleModel.fromFirestore(doc)).toList();
      _schedules = list;
      notifyListeners();
    });

    _activitySub = _firestore
        .collection(AppConstants.activityLogsCollection)
        .snapshots()
        .listen((snap) {
      final list =
          snap.docs.map((doc) => ActivityLogModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _activityLogs = list;
      notifyListeners();
    });
  }

  /// Saves or updates a work schedule for an employee.
  Future<bool> saveWorkSchedule({
    String? id,
    required String userId,
    required String userName,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final docRef = (id != null && id.isNotEmpty)
          ? _firestore.collection(AppConstants.workSchedulesCollection).doc(id)
          : _firestore.collection(AppConstants.workSchedulesCollection).doc();

      final schedule = WorkScheduleModel(
        id: docRef.id,
        userId: userId,
        userName: userName,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );
      await docRef.set(schedule.toMap());
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan jadwal kerja: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a work schedule by id.
  Future<bool> deleteWorkSchedule(String scheduleId) async {
    try {
      await _firestore
          .collection(AppConstants.workSchedulesCollection)
          .doc(scheduleId)
          .delete();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus jadwal kerja: $e';
      notifyListeners();
      return false;
    }
  }

  /// Manually creates or updates an attendance log record (Admin CRUD).
  Future<bool> saveAttendanceLog({
    String? id,
    required String userId,
    required String userName,
    required String userRole,
    required DateTime loginAt,
    DateTime? logoutAt,
    String status = 'tepat',
  }) async {
    try {
      final docRef = (id != null && id.isNotEmpty)
          ? _firestore.collection(AppConstants.attendanceLogsCollection).doc(id)
          : _firestore.collection(AppConstants.attendanceLogsCollection).doc();

      final log = AttendanceLogModel(
        id: docRef.id,
        userId: userId,
        userName: userName,
        userRole: userRole,
        loginAt: loginAt,
        logoutAt: logoutAt,
        status: status,
      );
      await docRef.set(log.toMap());
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan data absensi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deletes an attendance log by id.
  Future<bool> deleteAttendanceLog(String logId) async {
    try {
      await _firestore
          .collection(AppConstants.attendanceLogsCollection)
          .doc(logId)
          .delete();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus data absensi: $e';
      notifyListeners();
      return false;
    }
  }

  /// Records an activity audit log entry.
  static Future<void> logActivity({
    required String userId,
    required String userName,
    required String action,
    required String entity,
    String entityId = '',
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef =
          firestore.collection(AppConstants.activityLogsCollection).doc();
      await docRef.set({
        'userId': userId,
        'userName': userName,
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // Non-blocking audit logging
    }
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _scheduleSub?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }
}

