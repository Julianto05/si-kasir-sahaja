import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';

/// Donut Chart Widget displaying Payment Method Breakdown (Grafik Lingkar Metode Pembayaran).
class PaymentDonutChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const PaymentDonutChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Calculate breakdown
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
        label: 'Kartu Debit/Kredit',
        amount: cardTotal,
        color: const Color(0xFFF59E0B),
        icon: Icons.credit_card_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Metode Pembayaran',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut and Legend Layout
          totalRevenue == 0
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'Belum ada transaksi tercatat',
                      style: TextStyle(fontSize: 12, color: AppTheme.outline),
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Donut Canvas
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CustomPaint(
                        painter: _DonutChartPainter(
                          slices: slices,
                          total: totalRevenue,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.outline,
                                ),
                              ),
                              Text(
                                _formatCompact(totalRevenue),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Legend List
                    Expanded(
                      child: Column(
                        children: slices.map((s) {
                          final pct = totalRevenue > 0
                              ? (s.amount / totalRevenue) * 100
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.5),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
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

  _DonutChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 18.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      if (slice.amount <= 0) continue;
      final sweepAngle = (slice.amount / total) * 2 * math.pi;

      paint.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}
