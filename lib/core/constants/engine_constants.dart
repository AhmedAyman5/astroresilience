import '../models/engine_result.dart';

/// Tuning values of the Edge AI Engine (Layer 2). All documented here so the
/// team can explain — and change — every number the engine uses.
class EngineConstants {
  EngineConstants._();

  // --- Rolling window --------------------------------------------------------

  /// The engine looks at the last 12 readings (1 minute at 5 s interval).
  static const int windowSize = 12;

  /// "Current value" of a vital = average of the last 3 readings, so a single
  /// noisy reading cannot trigger an alert by itself.
  static const int smoothingReadings = 3;

  // --- Adaptive personal baseline (the "learning" part) ----------------------

  /// Starting guess before the engine has learned anything about this
  /// astronaut (typical resting values for a healthy adult).
  static const double baselineSeedHr = 70;
  static const double baselineSeedHrv = 50;

  /// EMA weight of each new calm reading. 0.05 = the baseline moves 5% of the
  /// way toward each new calm reading, so it adapts slowly over many minutes.
  static const double baselineAlpha = 0.05;

  /// For the first few calm readings we learn faster (30%) so the baseline
  /// quickly moves from the generic seed to this astronaut's real values.
  static const double baselineWarmupAlpha = 0.3;
  static const int baselineWarmupReadings = 5;

  // --- Shared severity scale -------------------------------------------------
  // Every metric is converted to one "level": 0 = fine, 0.5 = warning
  // threshold, 1.0 = critical threshold, up to 1.5 far beyond critical.
  static const double levelWarning = 0.5;
  static const double levelCritical = 1.0;
  static const double levelMax = 1.5;

  /// Highest level a risk can have while it is not allowed to be a warning
  /// yet (e.g. temperature not sustained for 3 readings).
  static const double levelBelowWarning = 0.49;

  /// When a combined rule has only ONE of its supporting signals instead of
  /// all of them, its level is multiplied by 0.8 — about "one notch lower".
  static const double singleSignalFactor = 0.8;

  /// Signal agreement used in the confidence %: 1.0 when all supporting
  /// signals of a rule are present, 0.5 when only part of them.
  static const double fullAgreement = 1.0;
  static const double partialAgreement = 0.5;

  // --- Risk score 0–100 ------------------------------------------------------
  // Score = points of the WORST risk + 25% of the weighted points of all
  // other risks. Points are aligned with the status bands:
  // level 0.5 (warning) = 40 points, level 1.0 (critical) = 70 points,
  // level 1.5 = 100 points.
  static const int scoreWarning = 40;
  static const int scoreCritical = 70;
  static const int scoreMax = 100;

  /// How much the other (non-worst) risks add on top of the worst one.
  static const double combinationFactor = 0.25;

  /// Weight of each risk when it is NOT the worst one. More dangerous risks
  /// add more: low oxygen is the most urgent, a calorie deficit the least.
  static const Map<RiskType, double> riskWeights = {
    RiskType.hypoxia: 1.0,
    RiskType.physiologicalStress: 0.8,
    RiskType.thermalStress: 0.8,
    RiskType.fatigue: 0.6,
    RiskType.nutritionDeficit: 0.5,
  };

  // --- Trend detection (slope over the window) -------------------------------

  /// Need at least 4 readings to talk about a trend.
  static const int trendMinSamples = 4;

  /// A risk is "rising" when its metric moves toward danger by at least 15%
  /// of the warning→critical gap per minute (e.g. SpO2 gap is 94→90 = 4 %,
  /// so SpO2 must fall by 0.6 % per minute or more).
  static const double trendRelativeSlopePerMinute = 0.15;

  /// The straight-line fit must explain at least 30% of the movement (R²),
  /// otherwise the "trend" is just noise.
  static const double trendMinR2 = 0.3;

  // --- Predictions -----------------------------------------------------------

  /// A WATCH prediction is made when a rising risk would reach its warning
  /// threshold within the next 10 minutes.
  static const int predictionHorizonMinutes = 10;

  /// ...and the metric is already a bit inside the approach zone.
  static const double watchMinLevel = 0.15;

  // --- Confidence % ----------------------------------------------------------
  // Active risks: 50% persistence (how many of the window readings are over
  // the threshold) + 30% signal agreement (all supporting signals present?)
  // + 20% data available (window full?).
  static const double confPersistenceWeight = 0.5;
  static const double confAgreementWeight = 0.3;
  static const double confFillWeight = 0.2;

  // WATCH predictions: 60% trend fit quality (R²) + 40% data available,
  // capped at 80% because the threshold has not been reached yet.
  static const double confWatchR2Weight = 0.6;
  static const double confWatchFillWeight = 0.4;
  static const double confWatchCap = 80;

  static const int confMin = 10;
  static const int confMax = 99;
}
