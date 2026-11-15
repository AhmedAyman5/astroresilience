import 'dart:math' as math;

import '../constants/engine_constants.dart';
import '../constants/thresholds.dart';
import '../constants/ui_constants.dart';
import '../models/vital_kind.dart';
import '../models/vital_reading.dart';
import 'stats.dart';

/// Range status of ONE vital (for the small dot on each vital card).
enum VitalRangeStatus {
  inRange,
  warning,
  critical;

  String get label => switch (this) {
    VitalRangeStatus.inRange => 'IN RANGE',
    VitalRangeStatus.warning => 'WARNING',
    VitalRangeStatus.critical => 'CRITICAL',
  };
}

/// Direction of the raw number (not of the risk): used for the trend arrows.
enum ValueDirection { up, flat, down }

/// A dashed threshold line drawn on a chart.
class ThresholdLine {
  const ThresholdLine({
    required this.value,
    required this.critical,
    required this.label,
  });

  final double value;

  /// true = critical line (red), false = warning line (amber).
  final bool critical;

  /// Short text drawn on the line, e.g. "WARN 94".
  final String label;
}

/// Current / min / max / average of a vital over a time range.
class SeriesStats {
  const SeriesStats({
    required this.current,
    required this.min,
    required this.max,
    required this.average,
  });

  final double current;
  final double min;
  final double max;
  final double average;

  static SeriesStats? of(List<double> values) {
    if (values.isEmpty) return null;
    return SeriesStats(
      current: values.last,
      min: values.reduce(math.min),
      max: values.reduce(math.max),
      average: mean(values),
    );
  }
}

/// Pure helper functions behind the vital cards and the Vitals charts.
/// Kept out of the widgets so they can be tested and explained on their own.
class VitalAnalysis {
  VitalAnalysis._();

  /// Readings in the last [range] before the newest reading
  /// (all readings when [range] is null = whole session).
  static List<VitalReading> inRange(
    List<VitalReading> history,
    Duration? range,
  ) {
    if (range == null || history.isEmpty) return history;
    final from = history.last.timestamp.subtract(range);
    // History is oldest first: find the first reading inside the range.
    var start = history.length;
    while (start > 0 && !history[start - 1].timestamp.isBefore(from)) {
      start--;
    }
    return history.sublist(start);
  }

  /// The last [n] readings (fewer at the start of a session).
  static List<VitalReading> lastN(List<VitalReading> history, int n) =>
      history.length <= n ? history : history.sublist(history.length - n);

  /// Is this vital out of range right now?
  ///
  /// Like the engine, we use the average of the last 3 readings, so one
  /// noisy reading does not light up a card that the engine ignores.
  /// - Heart rate only counts at LOW activity (a high heart rate during
  ///   exercise is normal).
  /// - HRV is judged as a drop versus the learned personal baseline.
  /// - Activity has no thresholds.
  static VitalRangeStatus status(
    VitalKind kind,
    List<VitalReading> history, {
    required double baselineHrv,
  }) {
    if (history.isEmpty || kind == VitalKind.activity) {
      return VitalRangeStatus.inRange;
    }
    final recent = lastN(history, EngineConstants.smoothingReadings);
    final value = mean(recent.map(kind.valueOf));

    switch (kind) {
      case VitalKind.heartRate:
        if (history.last.activity != ActivityLevel.low) {
          return VitalRangeStatus.inRange;
        }
        return _higherIsWorse(
          value,
          Thresholds.hrRestWarning.toDouble(),
          Thresholds.hrRestCritical.toDouble(),
        );
      case VitalKind.hrv:
        if (baselineHrv <= 0) return VitalRangeStatus.inRange;
        final drop = (baselineHrv - value) / baselineHrv;
        return _higherIsWorse(
          drop,
          Thresholds.hrvDropWarning,
          Thresholds.hrvDropCritical,
        );
      case VitalKind.spo2:
        if (value < Thresholds.spo2Critical) return VitalRangeStatus.critical;
        if (value < Thresholds.spo2Warning) return VitalRangeStatus.warning;
        return VitalRangeStatus.inRange;
      case VitalKind.temperature:
        return _higherIsWorse(
          value,
          Thresholds.tempWarning,
          Thresholds.tempCritical,
        );
      case VitalKind.activity:
        return VitalRangeStatus.inRange;
    }
  }

  static VitalRangeStatus _higherIsWorse(
    double value,
    double warning,
    double critical,
  ) {
    if (value > critical) return VitalRangeStatus.critical;
    if (value > warning) return VitalRangeStatus.warning;
    return VitalRangeStatus.inRange;
  }

  /// Direction of the number over the window: average of the last 3
  /// readings versus the first 3. Small changes (inside the dead band)
  /// count as flat.
  static ValueDirection direction(VitalKind kind, List<VitalReading> window) {
    const edge = UiConstants.trendEdgeReadings;
    if (window.length < edge * 2) return ValueDirection.flat;
    final values = window.map(kind.valueOf).toList();
    final first = mean(values.take(edge));
    final last = mean(values.skip(values.length - edge));
    final delta = last - first;
    final band = trendBand(kind);
    if (delta > band) return ValueDirection.up;
    if (delta < -band) return ValueDirection.down;
    return ValueDirection.flat;
  }

  static double trendBand(VitalKind kind) => switch (kind) {
    VitalKind.heartRate => UiConstants.trendBandHeartRate,
    VitalKind.hrv => UiConstants.trendBandHrv,
    VitalKind.spo2 => UiConstants.trendBandSpo2,
    VitalKind.temperature => UiConstants.trendBandTemperature,
    VitalKind.activity => UiConstants.trendBandActivity,
  };

  /// Warning + critical lines for a chart, straight from thresholds.dart.
  /// HRV lines move with the learned baseline (20% / 35% below it).
  static List<ThresholdLine> thresholdLines(
    VitalKind kind, {
    required double baselineHrv,
  }) {
    switch (kind) {
      case VitalKind.heartRate:
        return [
          ThresholdLine(
            value: Thresholds.hrRestWarning.toDouble(),
            critical: false,
            label: 'WARN ${Thresholds.hrRestWarning} AT REST',
          ),
          ThresholdLine(
            value: Thresholds.hrRestCritical.toDouble(),
            critical: true,
            label: 'CRIT ${Thresholds.hrRestCritical} AT REST',
          ),
        ];
      case VitalKind.hrv:
        final warnPct = (Thresholds.hrvDropWarning * 100).round();
        final critPct = (Thresholds.hrvDropCritical * 100).round();
        return [
          ThresholdLine(
            value: baselineHrv * (1 - Thresholds.hrvDropWarning),
            critical: false,
            label: 'WARN −$warnPct% VS BASELINE',
          ),
          ThresholdLine(
            value: baselineHrv * (1 - Thresholds.hrvDropCritical),
            critical: true,
            label: 'CRIT −$critPct% VS BASELINE',
          ),
        ];
      case VitalKind.spo2:
        return [
          ThresholdLine(
            value: Thresholds.spo2Warning.toDouble(),
            critical: false,
            label: 'WARN < ${Thresholds.spo2Warning}',
          ),
          ThresholdLine(
            value: Thresholds.spo2Critical.toDouble(),
            critical: true,
            label: 'CRIT < ${Thresholds.spo2Critical}',
          ),
        ];
      case VitalKind.temperature:
        return const [
          ThresholdLine(
            value: Thresholds.tempWarning,
            critical: false,
            label: 'WARN > ${Thresholds.tempWarning}',
          ),
          ThresholdLine(
            value: Thresholds.tempCritical,
            critical: true,
            label: 'CRIT > ${Thresholds.tempCritical}',
          ),
        ];
      case VitalKind.activity:
        return const [];
    }
  }

  static double minSpan(VitalKind kind) => switch (kind) {
    VitalKind.heartRate => UiConstants.minSpanHeartRate,
    VitalKind.hrv => UiConstants.minSpanHrv,
    VitalKind.spo2 => UiConstants.minSpanSpo2,
    VitalKind.temperature => UiConstants.minSpanTemperature,
    VitalKind.activity => 2,
  };

  /// Y-axis range for a chart: covers all [values] and [extra] values
  /// (threshold lines), is at least [minSpan] wide and has a little empty
  /// space above and below.
  static ({double min, double max}) yBounds(
    Iterable<double> values,
    double minSpan, {
    Iterable<double> extra = const [],
  }) {
    final all = [...values, ...extra];
    if (all.isEmpty) return (min: 0, max: minSpan);
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    final span = hi - lo;
    if (span < minSpan) {
      final mid = (lo + hi) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
    }
    final pad = (hi - lo) * UiConstants.chartPaddingFraction;
    return (min: lo - pad, max: hi + pad);
  }
}
