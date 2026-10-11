import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/store_settings_model.dart';

/// Service layer for managing general store and invoice settings in Cloud Firestore.
class StoreSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection(AppConstants.storeSettingsCollection).doc('general');

  /// Streams the store settings in real-time.
  Stream<StoreSettingsModel> streamSettings() {
    return _settingsDoc.snapshots().map((doc) {
      return StoreSettingsModel.fromFirestore(doc);
    });
  }

  /// Fetches one-time store settings.
  Future<StoreSettingsModel> getSettings() async {
    final doc = await _settingsDoc.get();
    return StoreSettingsModel.fromFirestore(doc);
  }

  /// Updates or creates the store settings document.
  Future<void> updateSettings(StoreSettingsModel settings) async {
    final data = settings.copyWith(updatedAt: DateTime.now()).toMap();
    await _settingsDoc.set(data, SetOptions(merge: true));
  }
}
