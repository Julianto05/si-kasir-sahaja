import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/shift_model.dart';
import '../../../providers/shift_provider.dart';
import '../../cashier/closing/shift_receipt_dialog.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Screen for Admin to view and monitor all cashier shift closing records.
class ShiftHistoryScreen extends StatelessWidget {
  const ShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final allShifts = shiftProvider.allShifts;

    double totalOmset = 0.0;
    double totalVariance = 0.0;
    int closedCount = 0;

    for (final s in allShifts) {
      if (s.isClosed) {
        totalOmset += s.totalSales;
        totalVariance += s.cashDifference;
        closedCount++;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Rekap Closing Kasir'),
      ),
      drawer: const AdminDrawer(currentRoute: 'shifts'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'shifts'),
      body: SafeArea(
        child: Column(
          children: [
            // Top Summary Bar
            Container(
              color: AppTheme.surfaceContainerLowest,
              padding: const EdgeInsets.all(AppTheme.containerPadding),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryBox(
                      'Shift Ditutup',
                      '$closedCount Shift',
                      AppTheme.primary,
                      Icons.history_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryBox(
                      'Total Omset Rekap',
                      CurrencyFormatter.format(totalOmset),
                      AppTheme.secondary,
                      Icons.payments_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryBox(
                      'Total Selisih',
                      CurrencyFormatter.format(totalVariance),
                      totalVariance == 0
                          ? AppTheme.secondary
                          : (totalVariance < 0 ? AppTheme.error : Colors.blue),
                      Icons.balance_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // Shifts List
            Expanded(
              child: allShifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.point_of_sale_outlined,
                              size: 48, color: AppTheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada riwayat closing shift kasir',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 700;

                        if (isDesktop) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              childAspectRatio: 2.1,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: allShifts.length,
                            itemBuilder: (context, index) {
                              final shift = allShifts[index];
                              return _ShiftHistoryCard(shift: shift);
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: allShifts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final shift = allShifts[index];
                            return _ShiftHistoryCard(shift: shift);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.numericSmallStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ShiftHistoryCard extends StatelessWidget {
  final ShiftModel shift;

  const _ShiftHistoryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final openStr = DateFormat('dd/MM HH:mm').format(shift.openedAt);
    final closeStr = shift.closedAt != null
        ? DateFormat('dd/MM HH:mm').format(shift.closedAt!)
        : 'Sedang Aktif';

    final isBalanced = shift.cashDifference == 0;
    final isShortage = shift.cashDifference < 0;

    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      elevation: 1,
      child: InkWell(
        onTap: () => ShiftReceiptDialog.show(context, shift),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: shift.isOpen
                  ? AppTheme.secondary.withValues(alpha: 0.5)
                  : AppTheme.outlineVariant.withValues(alpha: 0.4),
              width: shift.isOpen ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: shift.isOpen
                              ? AppTheme.secondaryContainer
                              : AppTheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Icon(
                          shift.isOpen
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          size: 16,
                          color: shift.isOpen
                              ? AppTheme.secondary
                              : AppTheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        shift.cashierName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: shift.isOpen
                          ? AppTheme.secondaryContainer
                          : (isBalanced
                              ? Colors.green.shade50
                              : (isShortage
                                  ? AppTheme.errorContainer
                                  : Colors.blue.shade50)),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      shift.isOpen
                          ? 'AKTIF'
                          : (isBalanced
                              ? 'MATCH'
                              : (isShortage ? 'MINUS' : 'PLUS')),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: shift.isOpen
                          ? AppTheme.secondary
                          : (isBalanced
                              ? Colors.green.shade800
                              : (isShortage
                                  ? AppTheme.error
                                  : Colors.blue.shade800)),
                      ),
                    ),
                  ),
                ],
              ),

              // Time
              Text(
                'Buka: $openStr • Tutup: $closeStr',
                style: const TextStyle(fontSize: 11, color: AppTheme.outline),
              ),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Omset',
                          style:
                              TextStyle(fontSize: 10, color: AppTheme.outline)),
                      Text(
                        CurrencyFormatter.format(shift.totalSales),
                        style: AppTheme.numericSmallStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Selisih Kas',
                          style:
                              TextStyle(fontSize: 10, color: AppTheme.outline)),
                      Text(
                        CurrencyFormatter.format(shift.cashDifference),
                        style: AppTheme.numericSmallStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isBalanced
                              ? AppTheme.secondary
                              : (isShortage ? AppTheme.error : Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
