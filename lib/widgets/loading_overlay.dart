import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A reusable full-screen loading overlay.
///
/// Displays a centered [CircularProgressIndicator] with an optional
/// [message] on a semi-transparent background. Used during auth
/// checks, data loading, and transaction processing.
class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
