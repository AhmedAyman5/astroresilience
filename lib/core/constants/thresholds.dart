/// Physiological thresholds used by the Edge AI Engine (Layer 2).
///
/// IMPORTANT: these are general physiology values chosen for the demo.
/// The team will verify them against NASA medical references before the
/// final pitch. Change values here only — never hard-code them elsewhere.
class Thresholds {
  Thresholds._();

  // Blood oxygen saturation (%). Lower is worse.
  static const int spo2Warning = 94;
  static const int spo2Critical = 90;

  // Heart rate (bpm) while activity is LOW. Higher is worse.
  static const int hrRestWarning = 100;
  static const int hrRestCritical = 120;

  // HRV drop versus the astronaut's personal baseline (fraction 0–1).
  static const double hrvDropWarning = 0.20;
  static const double hrvDropCritical = 0.35;

  // Skin temperature (°C), must be sustained for [tempSustainedReadings].
  static const double tempWarning = 37.5;
  static const double tempCritical = 38.0;
  static const int tempSustainedReadings = 3;

  // Energy deficit (kcal): estimated expenditure minus logged intake.
  static const int energyDeficitWarning = 500;
  static const int energyDeficitCritical = 900;
}
