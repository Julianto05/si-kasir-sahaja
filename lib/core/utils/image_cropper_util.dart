import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Utility class to decode and process images of ANY format (JPEG, PNG, WebP, GIF, BMP, etc.)
/// and crop them to an exact 1:1 square aspect ratio directly on-device using Skia engine.
class ImageCropperUtil {
  /// Detects image format from magic bytes.
  static String detectFormat(Uint8List bytes) {
    if (bytes.length >= 8) {
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return 'jpg';
      }
      // GIF: 47 49 46 38
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return 'gif';
      }
      // BMP: 42 4D
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return 'bmp';
      }
      // WebP: RIFF .... WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }
    return 'jpg';
  }

  /// Crops any image to an exact 1:1 square ratio from the center.
  ///
  /// Decodes any format supported by Flutter/Skia and returns crisp square byte data.
  static Future<Uint8List> cropToSquare(
    Uint8List rawBytes, {
    int maxDimension = 1024,
  }) async {
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final origWidth = image.width;
    final origHeight = image.height;
    final squareSide = math.min(origWidth, origHeight);

    // Center crop coordinates
    final cropX = (origWidth - squareSide) / 2.0;
    final cropY = (origHeight - squareSide) / 2.0;

    final targetSide = math.min(squareSide, maxDimension);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetSide.toDouble(), targetSide.toDouble()),
    );

    final srcRect = Rect.fromLTWH(
      cropX,
      cropY,
      squareSide.toDouble(),
      squareSide.toDouble(),
    );
    final dstRect = Rect.fromLTWH(
      0,
      0,
      targetSide.toDouble(),
      targetSide.toDouble(),
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    final croppedUiImage = await picture.toImage(targetSide, targetSide);
    final byteData = await croppedUiImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }
}
