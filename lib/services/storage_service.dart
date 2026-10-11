import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';

/// Service layer for uploading and managing files on Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a product image from an [XFile] to Firebase Storage.
  ///
  /// Storage path: `products/{productId}.jpg`
  /// Returns the downloadable URL.
  Future<String> uploadProductImage(XFile imageFile, String productId) async {
    final ref = _storage
        .ref()
        .child(AppConstants.productImagesPath)
        .child('$productId.jpg');

    final Uint8List bytes = await imageFile.readAsBytes();
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
    );

    final uploadTask = await ref.putData(bytes, metadata);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Uploads raw image bytes directly to Firebase Storage.
  Future<String> uploadProductImageBytes(Uint8List bytes, String productId) async {
    final ref = _storage
        .ref()
        .child(AppConstants.productImagesPath)
        .child('$productId.jpg');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
    );

    final uploadTask = await ref.putData(bytes, metadata);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Deletes a file from Firebase Storage given its downloadable URL or reference path.
  Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {
      // If the image doesn't exist or URL is invalid, ignore failure
    }
  }
}
