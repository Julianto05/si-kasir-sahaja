import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Service layer for Firebase Authentication and user management.
///
/// Handles sign-in, sign-out, user creation, and Firestore user data
/// retrieval. All role information is stored in Firestore `users/{uid}`,
/// NOT in Firebase Auth custom claims, to keep the architecture simple
/// and queryable.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of auth state changes (login/logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// Signs in with [email] and [password].
  ///
  /// Returns the [UserModel] from Firestore after successful authentication.
  /// Throws [AppAuthException] on failure.
  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw AppAuthException(
        code: 'user-not-found',
        message: 'Login gagal. Silakan coba lagi.',
      );
    }

    // Fetch user data from Firestore to get role
    final userData = await getUserData(user.uid);
    if (userData == null) {
      // User exists in Auth but not in Firestore — sign out
      await _auth.signOut();
      throw AppAuthException(
        code: 'user-not-found',
        message: 'Data pengguna tidak ditemukan. Hubungi admin.',
      );
    }

    // Check if account is active
    if (!userData.isActive) {
      await _auth.signOut();
      throw AppAuthException(
        code: 'user-disabled',
        message: 'Akun Anda telah dinonaktifkan. Hubungi admin.',
      );
    }

    return userData;
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetches the [UserModel] for [uid] from Firestore.
  ///
  /// Returns `null` if the document does not exist.
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Creates a new user account in Firebase Auth AND Firestore.
  ///
  /// Used by admin to create cashier accounts. The [role] should be
  /// either `'admin'` or `'kasir'`.
  Future<UserModel> createUserAccount({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    // Create the Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw AppAuthException(
        code: 'creation-failed',
        message: 'Gagal membuat akun. Silakan coba lagi.',
      );
    }

    final now = DateTime.now();
    final userModel = UserModel(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
      role: role,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    // Save user data to Firestore
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toMap());

    return userModel;
  }

  /// Updates the user's password.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna tidak terautentikasi.');
    await user.updatePassword(newPassword);
  }

  /// Updates user profile data in Firestore.
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
  }

  /// Translates Firebase Auth error codes to user-friendly Indonesian messages.
  static String getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'email-already-in-use':
        return 'Email sudah digunakan.';
      case 'weak-password':
        return 'Password terlalu lemah. Minimal 6 karakter.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'network-request-failed':
        return 'Gagal terhubung ke server. Periksa koneksi internet.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }
}

/// Custom auth exception for app-specific error cases.
class AppAuthException implements Exception {
  final String code;
  final String message;

  AppAuthException({required this.code, required this.message});

  @override
  String toString() => 'AppAuthException($code): $message';
}
