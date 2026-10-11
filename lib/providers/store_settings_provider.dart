import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/store_settings_model.dart';
import '../services/store_settings_service.dart';

/// Provider for managing store metadata, tax policies, and receipt templates.
class StoreSettingsProvider extends ChangeNotifier {
  final StoreSettingsService _settingsService = StoreSettingsService();

  StoreSettingsModel _settings = StoreSettingsModel(updatedAt: DateTime.now());
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<StoreSettingsModel>? _subscription;

  StoreSettingsProvider() {
    _initStream();
  }

  // ─── Getters ────────────────────────────────────────────────

  StoreSettingsModel get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Stream Initialization ──────────────────────────────────

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _settingsService.streamSettings().listen(
      (settings) {
        _settings = settings;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = 'Gagal memuat pengaturan toko: $error';
        notifyListeners();
      },
    );
  }

  // ─── Actions ────────────────────────────────────────────────

  /// Updates store settings in Firestore.
  Future<bool> updateSettings(StoreSettingsModel newSettings) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _settingsService.updateSettings(newSettings);
      _settings = newSettings;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan pengaturan: $e';
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
