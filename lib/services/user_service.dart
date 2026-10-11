import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';

import '../core/constants/app_constants.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service layer for managing application users (Admin & Cashier accounts).
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  /// Streams all system users ordered by role & name.
  Stream<List<UserModel>> streamUsers() {
    return _usersRef.snapshots().map((snap) {
      return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  /// Creates a new cashier user account in Firebase Auth AND Firestore.
  ///
  /// Uses a secondary Firebase App instance so the current Admin session
  /// remains authenticated while creating the cashier's auth credentials.
  Future<UserModel> createCashierUser({
    required String email,
    required String password,
    required String name,
  }) async {
    // 1. Initialize secondary app to prevent signing out the current admin
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('SecondaryApp');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = auth.FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AppAuthException(
          code: 'creation-failed',
          message: 'Gagal membuat akun kasir.',
        );
      }

      final now = DateTime.now();
      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        name: name.trim(),
        role: AppConstants.roleCashier,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // 2. Save user document in primary Firestore
      await _usersRef.doc(user.uid).set(userModel.toMap());

      // Sign out from secondary auth
      await secondaryAuth.signOut();

      return userModel;
    } on auth.FirebaseAuthException catch (e) {
      throw AppAuthException(
        code: e.code,
        message: AuthService.getErrorMessage(e.code),
      );
    }
  }

  /// Toggles active status of an account (Admin can disable/enable cashier).
  Future<void> toggleUserStatus(String uid, bool currentStatus) async {
    await _usersRef.doc(uid).update({
      'isActive': !currentStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Updates user display name.
  Future<void> updateUserProfile(String uid, {required String name}) async {
    await _usersRef.doc(uid).update({
      'name': name.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
