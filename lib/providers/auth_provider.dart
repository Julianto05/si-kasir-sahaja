import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide FirebaseAuthException;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Authentication states used to drive UI routing.
enum AuthStatus {
  /// Initial state — checking persistent auth.
  uninitialized,

  /// Auth check in progress.
  authenticating,

  /// User is signed in and [UserModel] is loaded.
  authenticated,

  /// No user is signed in.
  unauthenticated,
}

/// Provides authentication state and user data to the widget tree.
///
/// Listens to [FirebaseAuth.authStateChanges] and automatically fetches
/// the user's role from Firestore on login. The UI uses [status] and
/// [currentUser] to determine which screen to show.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _currentUser;
  String? _errorMessage;
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
      // Fetch full user data (including role) from Firestore
      final userData = await _authService.getUserData(firebaseUser.uid);

      if (userData == null || !userData.isActive) {
        // User exists in Auth but not in Firestore, or is disabled
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

  /// Signs in with email and password.
  ///
  /// Updates [status] to [AuthStatus.authenticating] during the process.
  /// On success, [status] becomes [AuthStatus.authenticated].
  /// On failure, [errorMessage] is set and [status] becomes [AuthStatus.unauthenticated].
  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signIn(email, password);
      _currentUser = user;
      _status = AuthStatus.authenticated;
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

  /// Signs out the current user.
  Future<void> signOut() async {
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

    final userData = await _authService.getUserData(_currentUser!.uid);
    if (userData != null && userData.isActive) {
      _currentUser = userData;
      notifyListeners();
    } else {
      await signOut();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
