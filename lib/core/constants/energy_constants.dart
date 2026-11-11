/// Energy balance model (used by the Predictive Nutrition Loop).
///
/// Expenditure is estimated from the activity level of each reading. The
/// mission menu (scheduled meals) is assumed to cover [plannedIntakePerMinute];
/// anything burned above it becomes a deficit, which only logged meals
/// (Phase 4) can pay back. At rest the menu covers slightly more than the
/// body burns, so the deficit slowly shrinks again. If scheduled meals are
/// skipped (NUTRITION_DEFICIT scenario) the menu covers nothing.
class EnergyConstants {
  EnergyConstants._();

  /// Estimated burn in kcal per minute for a ~75 kg adult
  /// (about 1, 3 and 5 METs: resting, station work, hard exercise).
  static const double kcalPerMinuteLow = 1.2;
  static const double kcalPerMinuteModerate = 3.5;
  static const double kcalPerMinuteHigh = 6.0;

  /// Scheduled mission menu: ~2,900 kcal per day ≈ 2.0 kcal per minute
  /// (ISS menus target roughly this for an active astronaut).
  static const double plannedIntakePerMinute = 2.0;

  /// DEMO ACCELERATION: 1 real second = 1 mission minute (×60).
  /// Without it an energy deficit would take hours to build up, which is
  /// impossible to show live to the judges.
  static const double demoTimeScale = 60;
}
