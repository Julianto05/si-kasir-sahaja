import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';

/// Animated Donut Chart Widget displaying Payment Method Breakdown.
///
/// Features smooth radial sweep animation on mount and progress bars
/// in the legend, responsive for mobile, tablet, and desktop.
class PaymentDonutChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const PaymentDonutChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    double cashTotal = 0.0;
    double qrisTotal = 0.0;
    double transferTotal = 0.0;
    double cardTotal = 0.0;

    for (final tx in transactions) {
      if (!tx.isCompleted) continue;
      switch (tx.paymentMethod.toLowerCase()) {
        case 'cash':
          cashTotal += tx.total;
          break;
        case 'qris':
          qrisTotal += tx.total;
          break;
        case 'transfer':
          transferTotal += tx.total;
          break;
        case 'card':
        case 'debit':
        case 'credit':
        case 'kredit':
          cardTotal += tx.total;
          break;
        default:
          cashTotal += tx.total;
      }
    }

    final totalRevenue = cashTotal + qrisTotal + transferTotal + cardTotal;

    final slices = [
      _PaymentSlice(
        label: 'Tunai (Cash)',
        amount: cashTotal,
        color: AppTheme.secondary,
        icon: Icons.payments_rounded,
      ),
      _PaymentSlice(
        label: 'QRIS',
        amount: qrisTotal,
        color: const Color(0xFF0284C7),
        icon: Icons.qr_code_2_rounded,
      ),
      _PaymentSlice(
        label: 'Transfer Bank',
        amount: transferTotal,
        color: const Color(0xFF8B5CF6),
        icon: Icons.account_balance_rounded,
      ),
      _PaymentSlice(
        label: 'Debit / Kredit',
        amount: cardTotal,
        color: const Color(0xFFF59E0B),
        icon: Icons.credit_card_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Komposisi Pembayaran',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Text(
                      'Proporsi metode transaksi pelanggan',
                      style: TextStyle(fontSize: 11, color: AppTheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut and Legend Layout
          totalRevenue == 0
              ? SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 36,
                          color: AppTheme.outline.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada data pembayaran tercatat',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutQuart,
                  builder: (context, progress, _) {
                    return Row(
                      children: [
                        // Animated Donut Canvas
                        SizedBox(
                          width: 126,
                          height: 126,
                          child: CustomPaint(
                            painter: _DonutChartPainter(
                              slices: slices,
                              total: totalRevenue,
                              progress: progress,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'OMSET',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: AppTheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatCompact(totalRevenue * progress),
                                    style: AppTheme.numericSmallStyle.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Legend List with mini progress bar
                        Expanded(
                          child: Column(
                            children: slices.map((s) {
                              final pct = totalRevenue > 0
                                  ? (s.amount / totalRevenue) * 100
                                  : 0.0;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: s.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            s.label,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${(pct * progress).toStringAsFixed(0)}%',
                                          style: AppTheme.numericSmallStyle
                                              .copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (pct / 100) * progress,
                                        minHeight: 4,
                                        backgroundColor:
                                            AppTheme.surfaceContainerLow,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                s.color),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    }
    return CurrencyFormatter.format(value);
  }
}

class _PaymentSlice {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _PaymentSlice({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_PaymentSlice> slices;
  final double total;
  final double progress;

  _DonutChartPainter({
    required this.slices,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 16.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppTheme.surfaceContainerLow;
    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    final maxSweep = 2 * math.pi * progress;
    double drawnSweep = 0.0;

    for (final slice in slices) {
      if (slice.amount <= 0) continue;
      final fullSliceSweep = (slice.amount / total) * 2 * math.pi;
      final remaining = maxSweep - drawnSweep;
      if (remaining <= 0) break;

      final currentSweep = math.min(fullSliceSweep, remaining);
      paint.color = slice.color;
      canvas.drawArc(
        rect,
        startAngle,
        currentSweep,
        false,
        paint,
      );

      startAngle += fullSliceSweep;
      drawnSweep += currentSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.progress != progress ||
        oldDelegate.slices != slices;
  }
}
