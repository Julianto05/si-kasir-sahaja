import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/transaction_model.dart';
import '../../../widgets/motion_widgets.dart';

/// Animated Sales Trend Bar Chart (Grafik Tren Penjualan 7 Hari Terakhir).
///
/// Features smooth upward bar growth animation and interactive tap selection
/// so users on mobile can inspect any day's sales figure.
class SalesTrendChart extends StatefulWidget {
  final List<TransactionModel> transactions;

  const SalesTrendChart({super.key, required this.transactions});

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<DateTime> last7Days = List.generate(7, (i) {
      return today.subtract(Duration(days: 6 - i));
    });

    final Map<DateTime, double> dailyTotals = {
      for (var d in last7Days) d: 0.0,
    };

    for (final tx in widget.transactions) {
      if (!tx.isCompleted) continue;
      final txDate =
          DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
      if (dailyTotals.containsKey(txDate)) {
        dailyTotals[txDate] = (dailyTotals[txDate] ?? 0.0) + tx.total;
      }
    }

    final maxVal = dailyTotals.values.fold(0.0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal == 0 ? 100000.0 : maxVal * 1.15;

    final activeIdx = _selectedIndex ?? 6; // default to Today
    final selectedDate = last7Days[activeIdx];
    final selectedAmount = dailyTotals[selectedDate] ?? 0.0;
    final selectedDateStr =
        DateFormat('EEEE, dd MMM', 'id_ID').format(selectedDate);

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
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppTheme.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tren Penjualan 7 Hari',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      selectedDateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: AnimatedCurrencyText(
                  value: selectedAmount,
                  style: AppTheme.numericSmallStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Chart Bars Canvas
          SizedBox(
            height: 165,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(last7Days.length, (index) {
                    final date = last7Days[index];
                    final amount = dailyTotals[date] ?? 0.0;
                    final rawFactor =
                        (amount / effectiveMax).clamp(0.05, 1.0);
                    final animatedFactor =
                        (rawFactor * progress).clamp(0.05, 1.0);

                    final isToday = index == 6;
                    final isSelected = activeIdx == index;
                    final dayName = DateFormat('E', 'id_ID').format(date);
                    final dateNum = DateFormat('dd/MM').format(date);

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _selectedIndex = index);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Amount Label on Top
                              if (amount > 0)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatCompact(amount),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppTheme.secondary
                                          : AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 12),
                              const SizedBox(height: 4),

                              // Animated Bar
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: animatedFactor,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: isSelected
                                              ? [
                                                  AppTheme.secondary,
                                                  const Color(0xFF10B981),
                                                ]
                                              : isToday
                                                  ? [
                                                      AppTheme.primary,
                                                      AppTheme.primary
                                                          .withValues(
                                                              alpha: 0.75),
                                                    ]
                                                  : [
                                                      AppTheme.primary
                                                          .withValues(
                                                              alpha: 0.75),
                                                      AppTheme.primary
                                                          .withValues(
                                                              alpha: 0.45),
                                                    ],
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(
                                              AppTheme.radiusSm),
                                          bottom: Radius.circular(3),
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.secondary
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Day Label
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.secondary
                                      : AppTheme.onSurface,
                                ),
                              ),
                              Text(
                                dateNum,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? AppTheme.secondary
                                      : AppTheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
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
    return value.toInt().toString();
  }
}
