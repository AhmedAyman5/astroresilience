import '../../core/models/scenario.dart';
import '../../core/models/vital_reading.dart';

/// The "target" body state of one scenario. The simulator drifts the vitals
/// toward these values gradually; it never jumps straight to them.
class ScenarioProfile {
  const ScenarioProfile({
    required this.restingHr,
    required this.hrv,
    required this.spo2,
    required this.temperature,
    required this.activity,
    this.occasionalModerate = false,
    this.mealsSkipped = false,
  });

  /// Heart rate at rest (activity adds on top, see TelemetryConstants).
  final double restingHr;

  /// HRV in ms. Fatigue and stress push it down.
  final double hrv;
  final double spo2;
  final double temperature;

  /// Main activity level during the scenario.
  final ActivityLevel activity;

  /// NOMINAL only: short moderate-activity stints now and then.
  final bool occasionalModerate;

  /// The astronaut skips the scheduled meals (energy deficit builds up).
  final bool mealsSkipped;
}

/// Target values for each scenario. Compare them with core/constants/
/// thresholds.dart to see which alerts each scenario should trigger.
class ScenarioProfiles {
  ScenarioProfiles._();

  static const Map<Scenario, ScenarioProfile> _profiles = {
    // Healthy calm day: nothing should trigger.
    Scenario.nominal: ScenarioProfile(
      restingHr: 68,
      hrv: 52,
      spo2: 98,
      temperature: 36.6,
      activity: ActivityLevel.low,
      occasionalModerate: true,
    ),
    // Hard exercise: HR ~123 (78 resting + 45 for high activity), HRV 32 ms ≈ 38%
    // below baseline → FATIGUE goes watch → warning → critical.
    Scenario.fatigueOnset: ScenarioProfile(
      restingHr: 78,
      hrv: 32,
      spo2: 97,
      temperature: 37.0,
      activity: ActivityLevel.high,
    ),
    // Oxygen problem at rest: SpO2 falls to 88 (< 90 critical), HR rises to
    // compensate.
    Scenario.hypoxiaEvent: ScenarioProfile(
      restingHr: 90,
      hrv: 42,
      spo2: 88,
      temperature: 36.7,
      activity: ActivityLevel.low,
    ),
    // Heat during work: temperature climbs past 38.0 °C (critical).
    Scenario.thermalStress: ScenarioProfile(
      restingHr: 88,
      hrv: 42,
      spo2: 97,
      temperature: 38.3,
      activity: ActivityLevel.moderate,
    ),
    // Long moderate work with missed meals: the energy deficit grows; HRV
    // ~17% down is the "fatigue marker".
    Scenario.nutritionDeficit: ScenarioProfile(
      restingHr: 76,
      hrv: 43,
      spo2: 97,
      temperature: 36.3,
      activity: ActivityLevel.moderate,
      mealsSkipped: true,
    ),
    // Rest after an event: back to (slightly better than) baseline.
    Scenario.recovery: ScenarioProfile(
      restingHr: 62,
      hrv: 58,
      spo2: 98,
      temperature: 36.5,
      activity: ActivityLevel.low,
    ),
  };

  static ScenarioProfile of(Scenario scenario) => _profiles[scenario]!;
}
