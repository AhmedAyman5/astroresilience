import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/console_card.dart';
import '../../../core/constants/engine_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/models/vital_kind.dart';
import '../../../core/models/vital_reading.dart';
import '../../../core/utils/vital_analysis.dart';
import '../../../layers/engine/engine_controller.dart';
import '../../../layers/telemetry/telemetry_controller.dart';

/// One chart on the Vitals tab: header with current value and
/// min / max / average for the selected range, then a line chart with dashed
/// warning (amber) and critical (red) threshold lines.
///
/// Rebuilds only when a new reading arrives or the range changes. The chart
/// animates the change, so the line slides left instead of flickering.
class VitalChartCard extends StatelessWidget {
  const VitalChartCard({super.key, required this.kind, required this.range});

  final VitalKind kind;

  /// Visible time range; null = whole session.
  final Duration? range;

  @override
  Widget build(BuildContext context) {
    context.select<TelemetryController, int>((t) => t.revision);
    final history = context.read<TelemetryController>().historyView;
    final baselineHrv = context.select<EngineController, double>(
      (e) => e.latest?.baselineHrv ?? EngineConstants.baselineSeedHrv,
    );

    final readings = VitalAnalysis.inRange(history, range);
    final values = readings.map(kind.valueOf).toList();
    final stats = SeriesStats.of(values);

    return ConsoleCard(
      label: '${kind.label} · ${kind.unit.toUpperCase()}',
      trailing: stats == null
          ? null
          : Text(
              kind.format(stats.current),
              style: AppTypography.vitalValue.copyWith(fontSize: 22),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kind == VitalKind.activity)
            _ActivityShare(readings: readings)
          else
            _StatsRow(kind: kind, stats: stats),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: UiConstants.chartHeight,
            child: readings.length < 2
                ? Center(
                    child: Text(
                      'Collecting readings…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : RepaintBoundary(
                    child: _Chart(
                      kind: kind,
                      readings: readings,
                      sessionStart: history.first.timestamp,
                      thresholds: VitalAnalysis.thresholdLines(
                        kind,
                        baselineHrv: baselineHrv,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.kind, required this.stats});
  final VitalKind kind;
  final SeriesStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String f(double? v) => v == null ? '--' : kind.format(v);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _Stat('MIN', f(s?.min)),
        _Stat('MAX', f(s?.max)),
        _Stat('AVG', s == null ? '--' : s.average.toStringAsFixed(1)),
      ],
    );
  }
}

/// For activity: share of time at each level in the range.
class _ActivityShare extends StatelessWidget {
  const _ActivityShare({required this.readings});
  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    final n = readings.length;
    String pct(ActivityLevel level) {
      if (n == 0) return '--';
      final count = readings.where((r) => r.activity == level).length;
      return '${(100 * count / n).round()}%';
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final level in ActivityLevel.values)
          _Stat(level.label.toUpperCase(), pct(level)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: AppTypography.consoleLabel),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.monoSmall.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

// --- The chart itself -------------------------------------------------------------

class _Chart extends StatelessWidget {
  const _Chart({
    required this.kind,
    required this.readings,
    required this.sessionStart,
    required this.thresholds,
  });

  final VitalKind kind;
  final List<VitalReading> readings;
  final DateTime sessionStart;
  final List<ThresholdLine> thresholds;

  bool get _isActivity => kind == VitalKind.activity;

  /// x = seconds since the session started. Keeping x absolute (not
  /// "seconds ago") is what makes the animation look like a smooth scroll.
  double _x(VitalReading r) =>
      r.timestamp.difference(sessionStart).inMilliseconds / 1000;

  @override
  Widget build(BuildContext context) {
    final spots = [for (final r in readings) FlSpot(_x(r), kind.valueOf(r))];
    final minX = spots.first.x;
    final maxX = spots.last.x;

    final ({double min, double max}) y = _isActivity
        // Fixed axis for the 3 activity levels (0 low … 2 high).
        ? (min: -0.3, max: ActivityLevel.values.length - 0.7)
        : VitalAnalysis.yBounds(
            spots.map((s) => s.y),
            VitalAnalysis.minSpan(kind),
            extra: thresholds.map((t) => t.value),
          );
    final yInterval = _isActivity ? 1.0 : _niceInterval((y.max - y.min) / 3);
    final xInterval = max((maxX - minX) / 2, 1.0);

    final lineColor = _isActivity ? AppColors.info : AppColors.primary;

    return LineChart(
      duration: UiConstants.chartAnimation,
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: y.min,
        maxY: y.max,
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: AppColors.border),
            left: BorderSide(color: AppColors.border),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border.withValues(alpha: 0.6),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _isActivity ? 40 : 34,
              interval: yInterval,
              getTitlesWidget: (value, meta) => _leftTitle(value, meta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: xInterval,
              getTitlesWidget: (value, meta) =>
                  _bottomTitle(value, meta, maxX),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            for (final t in thresholds)
              HorizontalLine(
                y: t.value,
                color: (t.critical ? AppColors.critical : AppColors.warning)
                    .withValues(alpha: 0.8),
                strokeWidth: 1,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 9,
                    color: t.critical ? AppColors.critical : AppColors.warning,
                  ),
                  labelResolver: (_) => t.label,
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: lineColor,
            barWidth: 2,
            isCurved: !_isActivity,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            // Activity = step chart with a shaded band underneath.
            isStepLineChart: _isActivity,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: _isActivity,
              color: AppColors.info.withValues(alpha: 0.12),
              cutOffY: y.min,
              applyCutOffY: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftTitle(double value, TitleMeta meta) {
    // Skip the labels at the very top/bottom edge (they are not round).
    if (value == meta.min || value == meta.max) return const SizedBox.shrink();
    final String text;
    if (_isActivity) {
      final i = value.round();
      if ((value - i).abs() > 0.01 || i < 0 || i > 2) {
        return const SizedBox.shrink();
      }
      text = const ['LOW', 'MOD', 'HIGH'][i];
    } else {
      text = value.toStringAsFixed(kind == VitalKind.temperature ? 1 : 0);
    }
    return SideTitleWidget(
      meta: meta,
      space: AppSpacing.xs,
      child: Text(text, style: AppTypography.monoSmall.copyWith(fontSize: 9)),
    );
  }

  /// Time labels relative to the newest reading: "-1:00", "NOW".
  /// fl_chart also puts labels on round steps that can sit right next to the
  /// edges; those are skipped so labels never overlap.
  Widget _bottomTitle(double value, TitleMeta meta, double maxX) {
    final span = meta.max - meta.min;
    final isEdge = value == meta.min || value == meta.max;
    final nearEdge =
        (value - meta.min) < span * 0.25 || (meta.max - value) < span * 0.25;
    if (!isEdge && nearEdge) return const SizedBox.shrink();
    final ago = (maxX - value).round();
    final text = ago <= 0
        ? 'NOW'
        : '-${ago ~/ 60}:${(ago % 60).toString().padLeft(2, '0')}';
    return SideTitleWidget(
      meta: meta,
      space: AppSpacing.xs,
      child: Text(text, style: AppTypography.monoSmall.copyWith(fontSize: 9)),
    );
  }

  /// Rounds a raw step to a "nice" number (1, 2, 2.5, 5 × 10^n) so grid
  /// labels read 60 / 80 / 100 instead of 61.4 / 79.8.
  static double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final exp = pow(10, (log(raw) / ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1
        ? 1.0
        : f <= 2
        ? 2.0
        : f <= 2.5
        ? 2.5
        : f <= 5
        ? 5.0
        : 10.0;
    return nice * exp;
  }
}
