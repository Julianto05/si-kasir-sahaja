import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/app_theme.dart';

/// A modern reusable barcode & QR scanner modal with animated laser scan line
/// and corner viewfinder brackets.
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

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final AnimationController _laserController;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
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
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(rawValue.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.76,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
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
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.containerPadding,
              vertical: 6,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF34D399),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        'Posisikan barcode di dalam kotak pemindai',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Scanner Camera Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),

                    // Viewfinder Frame Overlay with Animated Laser Line
                    SizedBox(
                      width: 260,
                      height: 180,
                      child: Stack(
                        children: [
                          // Corner brackets painter
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ScannerBracketPainter(
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ),

                          // Animated Laser Scan Line
                          AnimatedBuilder(
                            animation: _laserController,
                            builder: (context, _) {
                              final topOffset =
                                  14.0 + (_laserController.value * 150.0);
                              return Positioned(
                                top: topOffset,
                                left: 14,
                                right: 14,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF34D399),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF34D399)
                                            .withValues(alpha: 0.65),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Helper text pill
                    Positioned(
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.center_focus_strong_rounded,
                              size: 15,
                              color: Color(0xFF34D399),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mendeteksi barcode secara otomatis...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Toolbar (Torch & Camera Switch)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Lampu Senter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                FilledButton.tonalIcon(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.flip_camera_ios_rounded, size: 18),
                  label: const Text('Ganti Kamera'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    foregroundColor: Colors.white,
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

class _ScannerBracketPainter extends CustomPainter {
  final Color color;

  _ScannerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 14.0;

    // Top-left
    final tl = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(len, 0);
    canvas.drawPath(tl, paint);

    // Top-right
    final tr = Path()
      ..moveTo(size.width - len, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, len);
    canvas.drawPath(tr, paint);

    // Bottom-left
    final bl = Path()
      ..moveTo(0, size.height - len)
      ..lineTo(0, size.height - r)
      ..quadraticBezierTo(0, size.height, r, size.height)
      ..lineTo(len, size.height);
    canvas.drawPath(bl, paint);

    // Bottom-right
    final br = Path()
      ..moveTo(size.width - len, size.height)
      ..lineTo(size.width - r, size.height)
      ..quadraticBezierTo(
          size.width, size.height, size.width, size.height - r)
      ..lineTo(size.width, size.height - len);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
