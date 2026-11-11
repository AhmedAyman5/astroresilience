import '../../core/constants/engine_constants.dart';
import '../../core/models/engine_result.dart';
import '../../core/utils/stats.dart';
import 'risk_scoring.dart';

/// Trend of one metric over the rolling window.
class TrendAnalysis {
  const TrendAnalysis({
    required this.trend,
    required this.slopePerMinute,
    required this.r2,
  });

  /// Direction of the RISK (rising = getting worse).
  final RiskTrend trend;

  /// Raw slope of the metric (its own unit per minute).
  final double slopePerMinute;

  /// Fit quality 0–1.
  final double r2;

  static const TrendAnalysis none = TrendAnalysis(
    trend: RiskTrend.stable,
    slopePerMinute: 0,
    r2: 0,
  );
}

/// Detects trends with a straight-line fit (linear regression) over the
/// window, and estimates when a threshold will be crossed.
class TrendAnalyzer {
  TrendAnalyzer._();

  /// [times] and [values] must have the same length (oldest first).
  static TrendAnalysis analyze(
    List<DateTime> times,
    List<double> values,
    MetricScale scale,
  ) {
    if (values.length < EngineConstants.trendMinSamples) {
      return TrendAnalysis.none;
    }
    // x = minutes since the first reading of the window.
    final xs = [
      for (final t in times) t.difference(times.first).inMilliseconds / 60000,
    ];
    final fit = linearFit(xs, values);

    // Turn the slope into "speed toward danger", measured in
    // warning→critical gaps per minute, so one rule works for every metric.
    final towardDanger = scale.higherIsWorse ? fit.slope : -fit.slope;
    final relative = towardDanger / scale.gap;

    var trend = RiskTrend.stable;
    if (fit.r2 >= EngineConstants.trendMinR2) {
      if (relative >= EngineConstants.trendRelativeSlopePerMinute) {
        trend = RiskTrend.rising;
      } else if (relative <= -EngineConstants.trendRelativeSlopePerMinute) {
        trend = RiskTrend.falling;
      }
    }
    return TrendAnalysis(trend: trend, slopePerMinute: fit.slope, r2: fit.r2);
  }

  /// Minutes until [current] reaches [target] at [slopePerMinute], rounded
  /// up (at least 1). Null if the value is not moving toward the target.
  static int? minutesTo(double current, double target, double slopePerMinute) {
    if (slopePerMinute == 0) return null;
    final minutes = (target - current) / slopePerMinute;
    if (minutes <= 0) return null;
    final rounded = minutes.ceil();
    return rounded < 1 ? 1 : rounded;
  }
}
