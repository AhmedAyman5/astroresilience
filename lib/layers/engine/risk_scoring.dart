import 'dart:math';

import '../../core/constants/engine_constants.dart';
import '../../core/models/engine_result.dart';

/// The three points that define how bad a metric value is.
/// Works for "higher is worse" (heart rate) and "lower is worse" (SpO2):
/// the direction is read from whether critical is above or below warning.
class MetricScale {
  const MetricScale({
    required this.approach,
    required this.warning,
    required this.critical,
  });

  final double approach;
  final double warning;
  final double critical;

  bool get higherIsWorse => critical > warning;

  /// Distance between warning and critical (always positive).
  double get gap => (critical - warning).abs();

  /// Converts a value to the shared severity level:
  /// approach → 0, warning → 0.5, critical → 1.0, then up to 1.5 beyond.
  double level(double value) {
    // Flip "lower is worse" metrics so that bigger always means worse.
    final s = higherIsWorse ? 1.0 : -1.0;
    final x = value * s, a = approach * s, w = warning * s, c = critical * s;

    if (x <= a) return 0;
    if (x < w) return EngineConstants.levelWarning * (x - a) / (w - a);
    if (x < c) {
      return EngineConstants.levelWarning +
          (EngineConstants.levelCritical - EngineConstants.levelWarning) *
              (x - w) /
              (c - w);
    }
    final beyond =
        EngineConstants.levelCritical +
        (EngineConstants.levelMax - EngineConstants.levelCritical) *
            (x - c) /
            (c - w);
    return min(beyond, EngineConstants.levelMax);
  }
}

/// Turns risk levels into the 0–100 score, the status and severities.
class RiskScoring {
  RiskScoring._();

  /// Level → points, aligned with the status bands:
  /// 0 → 0, 0.5 (warning) → 40, 1.0 (critical) → 70, 1.5 → 100.
  static double points(double level) {
    const w = EngineConstants.levelWarning;
    const c = EngineConstants.levelCritical;
    const m = EngineConstants.levelMax;
    const sw = EngineConstants.scoreWarning;
    const sc = EngineConstants.scoreCritical;
    const sm = EngineConstants.scoreMax;
    final l = level.clamp(0.0, m);
    if (l <= w) return sw * l / w;
    if (l <= c) return sw + (sc - sw) * (l - w) / (c - w);
    return sc + (sm - sc) * (l - c) / (m - c);
  }

  /// Weighted risk score 0–100.
  /// = points of the worst risk + 25% × weighted points of the other risks.
  /// So one critical risk alone already gives a CRITICAL score, and several
  /// risks at once push the score higher (compound danger).
  static int combinedScore(Map<RiskType, double> levels) {
    if (levels.isEmpty) return 0;
    RiskType? worst;
    var worstPoints = -1.0;
    levels.forEach((type, level) {
      final p = points(level);
      if (p > worstPoints) {
        worstPoints = p;
        worst = type;
      }
    });
    var others = 0.0;
    levels.forEach((type, level) {
      if (type != worst) {
        others += (EngineConstants.riskWeights[type] ?? 0) * points(level);
      }
    });
    final score = worstPoints + EngineConstants.combinationFactor * others;
    return score.round().clamp(0, EngineConstants.scoreMax);
  }

  /// Status bands: 0–39 NORMAL, 40–69 WARNING, 70–100 CRITICAL.
  static RiskStatus statusForScore(int score) {
    if (score >= EngineConstants.scoreCritical) return RiskStatus.critical;
    if (score >= EngineConstants.scoreWarning) return RiskStatus.warning;
    return RiskStatus.normal;
  }

  static PredictionSeverity severityForLevel(double level) {
    if (level >= EngineConstants.levelCritical) {
      return PredictionSeverity.critical;
    }
    if (level >= EngineConstants.levelWarning) {
      return PredictionSeverity.warning;
    }
    return PredictionSeverity.watch;
  }
}
