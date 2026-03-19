import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../models/product_model.dart';

class PriceHistoryChart extends StatelessWidget {
  final List<PriceHistoryEntry> entries;

  const PriceHistoryChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data yet', style: TextStyle(color: ShadowTheme.textMuted)));
    }

    final prices = entries.map((e) => e.price).toList();
    final minP = prices.reduce((a, b) => a < b ? a : b) - 20;
    final maxP = prices.reduce((a, b) => a > b ? a : b) + 20;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minP,
          maxY: maxP,
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(entries.length, (i) => FlSpot(i.toDouble(), entries[i].price)),
              isCurved: true,
              color: ShadowTheme.accent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ShadowTheme.accent.withValues(alpha: 0.2), ShadowTheme.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
