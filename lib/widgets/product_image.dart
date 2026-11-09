import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Reusable widget for displaying product photos with strict 1:1 aspect ratio,
/// supporting both remote HTTP/HTTPS URLs and inline Base64 Data URLs,
/// animated loading placeholder, and graceful fallbacks.
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final String productName;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? fallbackWidget;

  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.productName,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.fallbackWidget,
  });

  static Uint8List? decodeBase64Image(String raw) {
    try {
      String clean = raw.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusMd);
    final cleanUrl = imageUrl?.trim();

    final isNetworkUrl =
        cleanUrl != null &&
        cleanUrl.isNotEmpty &&
        (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'));

    final isDataUri =
        cleanUrl != null &&
        (cleanUrl.startsWith('data:image/') ||
            (cleanUrl.length > 100 &&
                !isNetworkUrl &&
                !cleanUrl.contains(' ')));

    Widget imageContent;

    if (isNetworkUrl) {
      imageContent = Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppTheme.surfaceContainerLow,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppTheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return fallbackWidget ?? _buildDefaultFallback(context);
        },
      );
    } else if (isDataUri) {
      final bytes = decodeBase64Image(cleanUrl);
      if (bytes != null && bytes.isNotEmpty) {
        imageContent = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return fallbackWidget ?? _buildDefaultFallback(context);
          },
        );
      } else {
        imageContent = fallbackWidget ?? _buildDefaultFallback(context);
      }
    } else {
      imageContent = fallbackWidget ?? _buildDefaultFallback(context);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: radius,
      ),
      child: ClipRRect(borderRadius: radius, child: imageContent),
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    final name = productName.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Container(
      color: AppTheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: (width != null && width! <= 48) ? 14 : 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}
