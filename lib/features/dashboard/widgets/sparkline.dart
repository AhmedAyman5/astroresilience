import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/utils/vital_analysis.dart';

/// Tiny line chart (no axes, no touch) for the vital cards.
///
/// [xs] are seconds since the session start, so when a new reading arrives
/// the line slides left smoothly instead of redrawing from scratch.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.xs,
    required this.values,
    required this.color,
    required this.minSpan,
    this.step = false,
  });

  final List<double> xs;
  final List<double> values;
  final Color color;

  /// Minimum vertical range, so sensor noise is not zoomed into big waves.
  final double minSpan;

  /// Step chart (for activity levels) instead of a smooth line.
  final bool step;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox(height: UiConstants.sparklineHeight);
    }
    final y = VitalAnalysis.yBounds(values, minSpan);
    return SizedBox(
      height: UiConstants.sparklineHeight,
      child: RepaintBoundary(
        child: LineChart(
          duration: UiConstants.chartAnimation,
          LineChartData(
            minX: xs.first,
            maxX: xs.last,
            minY: y.min,
            maxY: y.max,
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    FlSpot(xs[i], values[i]),
                ],
                isCurved: !step,
                preventCurveOverShooting: true,
                isStepLineChart: step,
                color: color,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
