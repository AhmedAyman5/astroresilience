import 'vital_reading.dart';

/// The 5 signals measured by the smart patches. Used by the vital cards and
/// the charts so every screen labels them the same way.
enum VitalKind {
  heartRate,
  hrv,
  spo2,
  temperature,
  activity;

  /// Upper-case console label, e.g. "HEART RATE".
  String get label => switch (this) {
    VitalKind.heartRate => 'HEART RATE',
    VitalKind.hrv => 'HRV',
    VitalKind.spo2 => 'SPO2',
    VitalKind.temperature => 'SKIN TEMP',
    VitalKind.activity => 'ACTIVITY',
  };

  /// Unit shown next to the value.
  String get unit => switch (this) {
    VitalKind.heartRate => 'bpm',
    VitalKind.hrv => 'ms',
    VitalKind.spo2 => '%',
    VitalKind.temperature => '°C',
    VitalKind.activity => 'level',
  };

  /// Decimals used when printing the value.
  int get decimals => this == VitalKind.temperature ? 1 : 0;

  /// Numeric value of this vital in a reading. Activity is mapped to
  /// 0 = low, 1 = moderate, 2 = high so it can be charted.
  double valueOf(VitalReading r) => switch (this) {
    VitalKind.heartRate => r.heartRate.toDouble(),
    VitalKind.hrv => r.hrv.toDouble(),
    VitalKind.spo2 => r.spo2.toDouble(),
    VitalKind.temperature => r.temperature,
    VitalKind.activity => r.activity.index.toDouble(),
  };

  /// Formats a value for display (mono font in the UI).
  String format(double value) {
    if (this == VitalKind.activity) {
      final i = value.round().clamp(0, ActivityLevel.values.length - 1);
      return ActivityLevel.values[i].label.toUpperCase();
    }
    return value.toStringAsFixed(decimals);
  }
}
