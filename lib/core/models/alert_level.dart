import 'engine_result.dart';

/// What the dashboard shows as the overall state. It adds a 4th stage to the
/// engine's 3 statuses:
///
/// - NOMINAL: nothing predicted.
/// - WATCH: still NORMAL, but the engine sees a risk trending toward a
///   threshold. This is the "predict before it happens" stage, so it gets
///   its own color (info blue) and icon (radar), distinct from WARNING.
/// - WARNING / CRITICAL: the engine status.
enum AlertLevel {
  nominal,
  watch,
  warning,
  critical;

  String get label => switch (this) {
    AlertLevel.nominal => 'NOMINAL',
    AlertLevel.watch => 'WATCH',
    AlertLevel.warning => 'WARNING',
    AlertLevel.critical => 'CRITICAL',
  };

  /// Derives the alert level from one engine result (null = no data yet).
  static AlertLevel of(EngineResult? result) {
    if (result == null) return AlertLevel.nominal;
    switch (result.status) {
      case RiskStatus.critical:
        return AlertLevel.critical;
      case RiskStatus.warning:
        return AlertLevel.warning;
      case RiskStatus.normal:
        return result.predictions.isEmpty
            ? AlertLevel.nominal
            : AlertLevel.watch;
    }
  }

  /// Alert level of a single prediction.
  static AlertLevel ofSeverity(PredictionSeverity s) => switch (s) {
    PredictionSeverity.watch => AlertLevel.watch,
    PredictionSeverity.warning => AlertLevel.warning,
    PredictionSeverity.critical => AlertLevel.critical,
  };
}
