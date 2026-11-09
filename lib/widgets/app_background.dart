import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Decorative background wrapper with soft rounded geometric shapes,
/// curved header arc, and subtle gradient meshes so the UI never looks plain.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showHeaderArc;

  const AppBackground({
    super.key,
    required this.child,
    this.showHeaderArc = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Soft Gradient Mesh
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEEF2F6),
                Color(0xFFF8FAFC),
                Color(0xFFECFDF5),
                Color(0xFFEEF2FF),
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),

        // 2. Top Rounded Header Arc / Wave
        if (showHeaderArc)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 135,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.10),
                      AppTheme.secondary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(42),
                  ),
                ),
              ),
            ),
          ),

        // 3. Top-Right Layered Rounded Decorative Circles & Pill
        Positioned(
          top: -55,
          right: -45,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withValues(alpha: 0.12),
                    AppTheme.primary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.10),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 24,
          right: 28,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: 0.22,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: AppTheme.primary.withValues(alpha: 0.045),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4. Top-Left Soft Rounded Pill Shape
        Positioned(
          top: 75,
          left: -45,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 155,
                height: 105,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.075),
                      AppTheme.secondary.withValues(alpha: 0.025),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 5. Center-Right Floating Rounded Card Shape
        Positioned(
          top: 320,
          right: -40,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.secondary.withValues(alpha: 0.08),
                      AppTheme.primary.withValues(alpha: 0.025),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 6. Bottom-Left Soft Rounded Circle & Geometric Card
        Positioned(
          bottom: -65,
          left: -45,
          child: IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.09),
                    AppTheme.secondary.withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          left: 24,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: 0.18,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppTheme.secondary.withValues(alpha: 0.05),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.09),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 7. Main Content
        child,
      ],
    );
  }
}
