import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models/sale.dart';

class SalesGraphWidget extends StatelessWidget {
  final List<Sale> sales;

  const SalesGraphWidget({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    // Process sales data for the last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<int, double> salesByDay = {};

    for (int i = 0; i < 7; i++) {
      salesByDay[i] = 0.0;
    }

    for (final sale in sales) {
      final saleDate = DateTime.parse(sale.timestamp);
      final saleDay = DateTime(saleDate.year, saleDate.month, saleDate.day);
      final difference = today.difference(saleDay).inDays;

      if (difference >= 0 && difference < 7) {
        // 0 is today, 6 is 7 days ago
        // We want to map it such that index 0 is 6 days ago, index 6 is today
        final index = 6 - difference;
        salesByDay[index] = (salesByDay[index] ?? 0) + sale.totalAmount;
      }
    }

    final maxY = salesByDay.values.reduce((a, b) => a > b ? a : b);
    final interval = maxY > 0 ? maxY / 5 : 10.0;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.2, // Add some buffer
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => AppTheme.neutral800,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '₹${rod.toY.toStringAsFixed(2)}',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    final date = now.subtract(Duration(days: 6 - index));
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('E').format(date),
                        style: const TextStyle(
                          color: AppTheme.neutral600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                        color: AppTheme.neutral500,
                        fontSize: 10,
                      ),
                    );
                  },
                  interval: interval,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.neutral200,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (index) {
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: salesByDay[index] ?? 0,
                    color: AppTheme.accent500,
                    width: 16,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
