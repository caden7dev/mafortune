import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';

class ExpensePieChart extends StatelessWidget {
  final double recettes;
  final double depenses;

  const ExpensePieChart({
    super.key,
    required this.recettes,
    required this.depenses,
  });

  @override
  Widget build(BuildContext context) {
    final total = recettes + depenses;
    if (total == 0) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Aucune donnée à afficher', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final recettesPercent = (recettes / total) * 100;
    final depensesPercent = (depenses / total) * 100;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: recettes,
                  title: '${recettesPercent.toStringAsFixed(1)}%',
                  color: Colors.green,
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: depenses,
                  title: '${depensesPercent.toStringAsFixed(1)}%',
                  color: Colors.red,
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegend('Recettes', Colors.green),
            const SizedBox(width: 24),
            _buildLegend('Dépenses', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}