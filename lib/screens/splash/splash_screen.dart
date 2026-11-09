import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../main.dart';

/// Modern Splash Screen featuring the official brand artwork (assets/images/5.png)
/// with subtle ambient background motion and smooth progress bar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();

    // Navigate to AuthGate after splash delay
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const AuthGate(),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTabletOrDesktop = size.width >= 700;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Subtle modern ambient background circles
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.08),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withValues(alpha: 0.08),
                    AppTheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Splash Artwork Container
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: isTabletOrDesktop ? 320 : 240,
                          maxHeight: isTabletOrDesktop ? 320 : 240,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXxl,
                          ),
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              blurRadius: 36,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                          child: Image.asset(
                            'assets/images/5.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusXl,
                                ),
                              ),
                              child: const Icon(
                                Icons.point_of_sale_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // App Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                        child: const Text(
                          'SMART RETAIL POS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // App Title
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aplikasi Kasir Modern & Terpercaya',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Sleek Pill Progress Bar
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1900),
                            curve: Curves.easeInOutCubic,
                            builder: (context, value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: AppTheme.surfaceContainerHigh,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Menyiapkan ruang kerja kasir...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
