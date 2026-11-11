/// Demo scenarios of the telemetry simulator. They can be switched live; the
/// vitals then drift gradually (over ~1–2 minutes) to the new situation.
enum Scenario {
  nominal,
  fatigueOnset,
  hypoxiaEvent,
  thermalStress,
  nutritionDeficit,
  recovery;

  /// Upper-case code used in logs, e.g. "FATIGUE_ONSET".
  String get code => switch (this) {
    Scenario.nominal => 'NOMINAL',
    Scenario.fatigueOnset => 'FATIGUE_ONSET',
    Scenario.hypoxiaEvent => 'HYPOXIA_EVENT',
    Scenario.thermalStress => 'THERMAL_STRESS',
    Scenario.nutritionDeficit => 'NUTRITION_DEFICIT',
    Scenario.recovery => 'RECOVERY',
  };

  String get label => switch (this) {
    Scenario.nominal => 'Nominal',
    Scenario.fatigueOnset => 'Fatigue onset',
    Scenario.hypoxiaEvent => 'Hypoxia event',
    Scenario.thermalStress => 'Thermal stress',
    Scenario.nutritionDeficit => 'Nutrition deficit',
    Scenario.recovery => 'Recovery',
  };

  /// One line explaining what the simulator does in this scenario.
  String get description => switch (this) {
    Scenario.nominal => 'Calm day in the habitat, mostly low activity.',
    Scenario.fatigueOnset =>
      'Long hard exercise: heart rate up, HRV falling.',
    Scenario.hypoxiaEvent => 'Cabin O2 problem: SpO2 slowly dropping.',
    Scenario.thermalStress =>
      'Suit cooling issue during work: temperature rising.',
    Scenario.nutritionDeficit =>
      'Sustained work with missed meals: energy deficit grows.',
    Scenario.recovery => 'Rest after the event: vitals return to baseline.',
  };
}
