import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';

class LineChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final bool showRecettes;

  const LineChartWidget({
    super.key,
    required this.weeklyData,
    required this.showRecettes,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < weeklyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(weeklyData[index]['jour']),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 45),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: weeklyData.asMap().entries.map((entry) {
                final value = showRecettes
                    ? entry.value['recettes']
                    : entry.value['depenses'];
                return FlSpot(entry.key.toDouble(), value);
              }).toList(),
              isCurved: true,
              color: showRecettes ? AppColors.primaryGreen : AppColors.expenseRed,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: (showRecettes ? AppColors.primaryGreen : AppColors.expenseRed)
                    .withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}