import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/app_theme.dart';

/// A modern reusable barcode & QR scanner modal.
///
/// Returns the detected barcode [String] when scanned, or `null` if closed.
class BarcodeScannerModal extends StatefulWidget {
  final String title;

  const BarcodeScannerModal({
    super.key,
    this.title = 'Pindai Barcode Produk',
  });

  /// Static helper to show this scanner as a bottom sheet.
  static Future<String?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerModal(
        title: title ?? 'Pindai Barcode Produk',
      ),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _hasDetected = true;
        Navigator.of(context).pop(rawValue.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.inverseSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.outline.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.containerPadding,
              vertical: 8,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.secondaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.inverseOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.inverseOnSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scanner Camera Area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                ),

                // Viewfinder Frame Overlay
                Container(
                  width: 260,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.secondaryContainer,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),

                // Helper text
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'Arahkan kamera tepat ke barcode produk',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Toolbar (Torch & Camera Switch)
          Padding(
            padding: const EdgeInsets.all(AppTheme.containerPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on_rounded),
                  tooltip: 'Nyalakan Senter',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    foregroundColor: AppTheme.onSurface,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.flip_camera_ios_rounded),
                  tooltip: 'Ganti Kamera',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceContainerHighest,
                    foregroundColor: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
