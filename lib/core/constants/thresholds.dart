/// Physiological thresholds used by the Edge AI Engine (Layer 2).
///
/// IMPORTANT: these are general physiology values chosen for the demo.
/// The team will verify them against NASA medical references before the
/// final pitch. Change values here only — never hard-code them elsewhere.
///
/// Every metric has 3 points:
/// - "approach": the start of the WATCH zone. Below it nothing is reported.
///   Between approach and warning the engine only predicts (if trending).
/// - "warning" and "critical": the official thresholds from the project spec.
class Thresholds {
  Thresholds._();

  // Blood oxygen saturation (%). Lower is worse.
  static const int spo2Approach = 96;
  static const int spo2Warning = 94;
  static const int spo2Critical = 90;

  // Heart rate (bpm) while activity is LOW. Higher is worse.
  static const int hrRestApproach = 85;
  static const int hrRestWarning = 100;
  static const int hrRestCritical = 120;

  // HRV drop versus the astronaut's personal baseline (fraction 0–1).
  static const double hrvDropApproach = 0.08;
  static const double hrvDropWarning = 0.20;
  static const double hrvDropCritical = 0.35;

  // Skin temperature (°C), must be sustained for [tempSustainedReadings].
  static const double tempApproach = 37.1;
  static const double tempWarning = 37.5;
  static const double tempCritical = 38.0;
  static const int tempSustainedReadings = 3;

  // Energy deficit (kcal): estimated expenditure minus logged intake.
  static const int energyDeficitApproach = 200;
  static const int energyDeficitWarning = 500;
  static const int energyDeficitCritical = 900;

  // --- Supporting signals used by the combined rules ------------------------

  /// FATIGUE: heart rate at/above this during exercise counts as "high HR".
  static const int fatigueHrHigh = 110;

  /// FATIGUE: "sustained high activity" = at least
  /// [fatigueMinHighActivityReadings] HIGH readings among the last
  /// [fatigueRecentReadings].
  static const int fatigueRecentReadings = 6;
  static const int fatigueMinHighActivityReadings = 3;

  /// NUTRITION_DEFICIT: an HRV drop of 10%+ counts as a fatigue marker.
  static const double nutritionHrvMarker = 0.10;

  /// Heart rate this much above the personal baseline (15%) counts as
  /// "elevated" (e.g. the body compensating for low oxygen or heat).
  static const double hrElevatedRatio = 0.15;
}
