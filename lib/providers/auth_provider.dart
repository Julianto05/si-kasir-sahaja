import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide FirebaseAuthException;
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Authentication states used to drive UI routing.
enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  unauthenticated,
}

/// Provides authentication state, user data, and attendance login/logout tracking (PRD Section 5.1 & 5.10).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _currentUser;
  String? _errorMessage;
  String? _activeAttendanceId;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider() {
    _init();
  }

  // ─── Getters ────────────────────────────────────────────────

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading =>
      _status == AuthStatus.uninitialized ||
      _status == AuthStatus.authenticating;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isCashier => _currentUser?.isCashier ?? false;

  bool hasPermission(String permissionKey) =>
      _currentUser?.hasPermission(permissionKey) ?? false;

  // ─── Initialization ─────────────────────────────────────────

  void _init() {
    _authSubscription = _authService.authStateChanges.listen(
      _onAuthStateChanged,
      onError: (error) {
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
        notifyListeners();
      },
    );
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      final userData = await _authService.getUserData(firebaseUser.uid);

      if (userData == null || !userData.isActive) {
        await _authService.signOut();
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
      } else {
        _currentUser = userData;
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
    }

    notifyListeners();
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Signs in with email and password and records attendance login log.
  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(email, password);
      _currentUser = user;
      _status = AuthStatus.authenticated;

      // Record attendance login (PRD Section 5.1 & 5.10)
      await _recordAttendanceLogin(user);

      notifyListeners();
      return true;
    } on AppAuthException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      _errorMessage = AuthService.getErrorMessage(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> _recordAttendanceLogin(UserModel user) async {
    try {
      final now = DateTime.now();
      String status = 'tepat';

      // Check work schedule start time if configured
      final schedSnap = await _firestore
          .collection(AppConstants.workSchedulesCollection)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (schedSnap.docs.isNotEmpty) {
        final startStr =
            schedSnap.docs.first.data()['startTime'] as String? ?? '08:00';
        final parts = startStr.split(':');
        if (parts.length == 2) {
          final startHour = int.tryParse(parts[0]) ?? 8;
          final startMin = int.tryParse(parts[1]) ?? 0;
          final scheduledStart =
              DateTime(now.year, now.month, now.day, startHour, startMin)
                  .add(const Duration(minutes: 15)); // 15 min grace period
          if (now.isAfter(scheduledStart)) {
            status = 'terlambat';
          }
        }
      }

      final docRef =
          _firestore.collection(AppConstants.attendanceLogsCollection).doc();
      await docRef.set({
        'userId': user.uid,
        'userName': user.name,
        'userRole': user.role,
        'loginAt': Timestamp.fromDate(now),
        'logoutAt': null,
        'status': status,
      });
      _activeAttendanceId = docRef.id;
    } catch (_) {
      // Non-blocking attendance logging
    }
  }

  /// Signs out the current user and updates attendance logout timestamp.
  Future<void> signOut() async {
    try {
      if (_activeAttendanceId != null) {
        await _firestore
            .collection(AppConstants.attendanceLogsCollection)
            .doc(_activeAttendanceId)
            .update({
          'logoutAt': Timestamp.fromDate(DateTime.now()),
        });
        _activeAttendanceId = null;
      }
    } catch (_) {}

    await _authService.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears any existing error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refreshes the current user's data from Firestore.
  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    try {
      final updated = await _authService.getUserData(_currentUser!.uid);
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
