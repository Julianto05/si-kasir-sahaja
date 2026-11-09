import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Provider for managing cashier and admin users, employee profiles, and permissions (PRD Section 3 & 5.10).
class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  List<UserModel> _users = [];
  String _selectedRole = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<UserModel>>? _subscription;

  UserProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedRole => _selectedRole;
  String get searchQuery => _searchQuery;

  List<UserModel> get allUsers => _users;

  List<UserModel> get cashiers =>
      _users.where((u) => u.role == AppConstants.roleCashier).toList();

  List<UserModel> get admins =>
      _users.where((u) => u.role == AppConstants.roleAdmin).toList();

  /// Filtered users list.
  List<UserModel> get filteredUsers {
    return _users.where((u) {
      if (_selectedRole != 'all' && u.role != _selectedRole) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = u.name.toLowerCase().contains(q);
        final matchEmail = u.email.toLowerCase().contains(q);
        final matchPosition = u.position.toLowerCase().contains(q);
        if (!matchName && !matchEmail && !matchPosition) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ─── Stream Initialization ──────────────────────────────────

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _userService.streamUsers().listen(
      (users) {
        _users = users;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data pengguna: $error';
        notifyListeners();
      },
    );
  }

  // ─── Filters ────────────────────────────────────────────────

  void setRoleFilter(String role) {
    _selectedRole = role;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Creates a new cashier/staff account with optional phone, position, and permissions.
  Future<bool> createCashier({
    required String email,
    required String password,
    required String name,
    String phone = '',
    String position = 'Kasir',
    List<String> permissions = const [],
    String? workScheduleId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.createCashierUser(
        email: email,
        password: password,
        name: name,
        phone: phone,
        position: position,
        permissions: permissions,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal membuat akun kasir: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggles user active status.
  Future<bool> toggleUserStatus(UserModel user) async {
    try {
      await _userService.toggleUserStatus(user.uid, user.isActive);
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mengubah status pengguna: $e';
      notifyListeners();
      return false;
    }
  }

  /// Updates user display name, phone, position, and permissions.
  Future<bool> updateUserProfile(
    UserModel user,
    String newName, {
    String? phone,
    String? position,
    List<String>? permissions,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateUserProfile(
        user.uid,
        name: newName,
        phone: phone,
        position: position,
        permissions: permissions,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui profil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates user display name, phone, position, and permissions by uid.
  Future<bool> updateUserProfileAndPermissions({
    required String uid,
    required String name,
    String? phone,
    String? position,
    List<String>? permissions,
    String? workScheduleId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateUserProfile(
        uid,
        name: name,
        phone: phone,
        position: position,
        permissions: permissions,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui profil: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
