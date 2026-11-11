import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/constants/energy_constants.dart';
import '../../core/models/vital_reading.dart';

/// Tracks the astronaut's energy balance (Layer 3 input to the engine).
///
/// - Expenditure: estimated from the activity level of every reading.
/// - Planned intake: the scheduled mission menu covers ~2 kcal per minute
///   (unless meals are skipped).
/// - Logged intake: meals the astronaut logs (Phase 4) via [addIntake].
///
/// Deficit = expenditure − planned intake − logged intake, never below 0
/// (surplus calories are not "banked" in this demo model).
///
/// Time is accelerated (see EnergyConstants.demoTimeScale) so a deficit can
/// build up during a live demo.
class EnergyBalanceService extends ChangeNotifier {
  double _deficit = 0;
  double _totalExpenditure = 0;
  double _totalIntake = 0;
  double _missionMinutes = 0;

  /// Current energy deficit in kcal (0 = covered).
  double get deficitKcal => _deficit;

  /// Total estimated burn this session (kcal).
  double get totalExpenditureKcal => _totalExpenditure;

  /// Total kcal logged by the astronaut this session.
  double get totalIntakeKcal => _totalIntake;

  /// Simulated mission time covered by this session (minutes).
  double get missionMinutes => _missionMinutes;

  /// Estimated burn rate for an activity level.
  static double kcalPerMinute(ActivityLevel activity) => switch (activity) {
    ActivityLevel.low => EnergyConstants.kcalPerMinuteLow,
    ActivityLevel.moderate => EnergyConstants.kcalPerMinuteModerate,
    ActivityLevel.high => EnergyConstants.kcalPerMinuteHigh,
  };

  /// Adds the energy used since the previous reading.
  /// [realInterval] is the real time between readings (2 / 5 / 10 s).
  /// [scheduledMealsEaten] is false when the astronaut skips the planned
  /// menu (simulated NUTRITION_DEFICIT scenario): then nothing covers the burn.
  void recordReading(
    VitalReading reading,
    Duration realInterval, {
    bool scheduledMealsEaten = true,
  }) {
    final minutes =
        realInterval.inMilliseconds / 60000 * EnergyConstants.demoTimeScale;
    final burned = kcalPerMinute(reading.activity) * minutes;
    final planned = scheduledMealsEaten
        ? EnergyConstants.plannedIntakePerMinute * minutes
        : 0.0;

    _missionMinutes += minutes;
    _totalExpenditure += burned;
    _deficit = max(0, _deficit + burned - planned);
    notifyListeners();
  }

  /// Logs eaten calories (Phase 4: meal × consumption %). Reduces the deficit;
  /// the engine sees the change on the next reading.
  void addIntake(double kcal) {
    if (kcal <= 0) return;
    _totalIntake += kcal;
    _deficit = max(0, _deficit - kcal);
    notifyListeners();
  }

  void reset() {
    _deficit = 0;
    _totalExpenditure = 0;
    _totalIntake = 0;
    _missionMinutes = 0;
    notifyListeners();
  }
}
