import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction_model.dart';

/// Sales Trend Bar Chart (Grafik Tren Penjualan 7 Hari Terakhir).
class SalesTrendChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const SalesTrendChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Group transactions by the last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<DateTime> last7Days = List.generate(7, (i) {
      return today.subtract(Duration(days: 6 - i));
    });

    final Map<DateTime, double> dailyTotals = {
      for (var d in last7Days) d: 0.0,
    };

    for (final tx in transactions) {
      if (!tx.isCompleted) continue;
      final txDate = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
      if (dailyTotals.containsKey(txDate)) {
        dailyTotals[txDate] = (dailyTotals[txDate] ?? 0.0) + tx.total;
      }
    }

    final maxVal = dailyTotals.values.fold(0.0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal == 0 ? 100000.0 : maxVal * 1.15;

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
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: AppTheme.secondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tren Penjualan (7 Hari Terakhir)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'Maks: ${CurrencyFormatter.format(maxVal)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart Bars Canvas
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7Days.map((date) {
                final amount = dailyTotals[date] ?? 0.0;
                final heightFactor = (amount / effectiveMax).clamp(0.04, 1.0);
                final isToday = date.day == today.day &&
                    date.month == today.month &&
                    date.year == today.year;
                final dayName = DateFormat('E', 'id_ID').format(date);
                final dateNum = DateFormat('dd/MM').format(date);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Amount Tooltip on Hover/Top
                        if (amount > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatCompact(amount),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? AppTheme.secondary
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 11),
                        const SizedBox(height: 4),

                        // Animated Bar
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: isToday
                                        ? [
                                            AppTheme.secondary,
                                            AppTheme.secondary
                                                .withValues(alpha: 0.7),
                                          ]
                                        : [
                                            AppTheme.primary,
                                            AppTheme.primary
                                                .withValues(alpha: 0.65),
                                          ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppTheme.radiusSm),
                                  ),
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
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? AppTheme.secondary
                                : AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          dateNum,
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? AppTheme.secondary : AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
