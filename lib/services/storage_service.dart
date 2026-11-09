import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/image_cropper_util.dart';

/// Service layer for uploading and managing files on Firebase Storage with support for all image formats,
/// including automatic resilient fallback to inline Base64 Data URL if Cloud Storage is unprovisioned or unreachable.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Determines MIME type from file name/path or byte signature.
  static String getMimeType(String fileNameOrPath, [Uint8List? bytes]) {
    final lower = fileNameOrPath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';

    if (bytes != null && bytes.isNotEmpty) {
      final detected = ImageCropperUtil.detectFormat(bytes);
      switch (detected) {
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'gif':
          return 'image/gif';
        case 'bmp':
          return 'image/bmp';
        case 'jpg':
        default:
          return 'image/jpeg';
      }
    }

    return 'image/jpeg';
  }

  /// Determines file extension based on MIME type.
  static String getExtension(String fileNameOrPath, [Uint8List? bytes]) {
    final mime = getMimeType(fileNameOrPath, bytes);
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
        return 'bmp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  /// Uploads a product image from an [XFile] to Firebase Storage with automatic Data URL fallback.
  Future<String> uploadProductImage(XFile imageFile, String productId) async {
    final Uint8List rawBytes = await imageFile.readAsBytes();
    // Ensure square crop 1:1 if not already cropped
    final Uint8List squareBytes = await ImageCropperUtil.cropToSquare(
      rawBytes,
      maxDimension: 512,
    );

    final fileName = imageFile.name.isNotEmpty
        ? imageFile.name
        : imageFile.path;
    final ext = getExtension(fileName, squareBytes);

    return await uploadProductImageBytes(squareBytes, productId, format: ext);
  }

  /// Uploads raw image bytes directly to Firebase Storage with explicit or auto-detected format,
  /// with seamless fallback to inline Base64 Data URL if Storage reference is unavailable.
  Future<String> uploadProductImageBytes(
    Uint8List bytes,
    String productId, {
    String? format,
  }) async {
    final detected = format ?? ImageCropperUtil.detectFormat(bytes);
    final ext = detected.isNotEmpty ? detected : 'png';
    final mime = getMimeType('image.$ext', bytes);

    try {
      final ref = _storage
          .ref()
          .child(AppConstants.productImagesPath)
          .child('$productId.$ext');

      final metadata = SettableMetadata(
        contentType: mime,
        cacheControl: 'public, max-age=31536000',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'format': ext,
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint(
        'Firebase Storage upload unavailable ($e). Falling back to resilient inline Base64 data URI.',
      );
      final base64String = base64Encode(bytes);
      return 'data:$mime;base64,$base64String';
    }
  }

  /// Deletes a file from Firebase Storage given its downloadable URL or reference path.
  Future<void> deleteImageByUrl(String imageUrl) async {
    if (imageUrl.startsWith('data:')) {
      // Inline Data URL requires no remote file deletion
      return;
    }
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {
      // If the image doesn't exist or URL is invalid, ignore failure
    }
  }
}
