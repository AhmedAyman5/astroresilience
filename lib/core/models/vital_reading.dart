import 'package:flutter/foundation.dart';

import '../utils/time_format.dart';

/// Physical activity level reported by the smart patches.
enum ActivityLevel {
  low,
  moderate,
  high;

  /// Value used in JSON: "low" / "moderate" / "high".
  String get jsonValue => name;

  String get label => switch (this) {
    ActivityLevel.low => 'Low',
    ActivityLevel.moderate => 'Moderate',
    ActivityLevel.high => 'High',
  };

  /// Strict parser for our own JSON. Unknown values fall back to [low].
  /// (The tolerant parser for external NASA files lives in ReplayParser.)
  static ActivityLevel fromJson(Object? value) {
    for (final level in ActivityLevel.values) {
      if (level.name == value) return level;
    }
    return ActivityLevel.low;
  }
}

/// One reading from the (simulated) smart patches. Immutable.
///
/// JSON keys are fixed by the project spec:
/// {"timestamp":"2026-11-14T10:30:00","heart_rate":78,"hrv":42,"spo2":97,
///  "temperature":36.6,"activity":"low"}
@immutable
class VitalReading {
  const VitalReading({
    required this.timestamp,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.temperature,
    required this.activity,
  });

  final DateTime timestamp;

  /// Heart rate in beats per minute.
  final int heartRate;

  /// Heart rate variability in milliseconds (higher = more rested).
  final int hrv;

  /// Blood oxygen saturation in percent.
  final int spo2;

  /// Skin temperature in °C, rounded to 1 decimal (use [roundTemperature]).
  final double temperature;

  final ActivityLevel activity;

  /// Rounds a temperature to 1 decimal, as required by the spec.
  static double roundTemperature(double celsius) =>
      (celsius * 10).roundToDouble() / 10;

  VitalReading copyWith({
    DateTime? timestamp,
    int? heartRate,
    int? hrv,
    int? spo2,
    double? temperature,
    ActivityLevel? activity,
  }) {
    return VitalReading(
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      hrv: hrv ?? this.hrv,
      spo2: spo2 ?? this.spo2,
      temperature: temperature ?? this.temperature,
      activity: activity ?? this.activity,
    );
  }

  factory VitalReading.fromJson(Map<String, dynamic> json) {
    return VitalReading(
      timestamp: DateTime.parse(json['timestamp'] as String),
      heartRate: (json['heart_rate'] as num).round(),
      hrv: (json['hrv'] as num).round(),
      spo2: (json['spo2'] as num).round(),
      temperature: roundTemperature((json['temperature'] as num).toDouble()),
      activity: ActivityLevel.fromJson(json['activity']),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': TimeFormat.isoSeconds(timestamp),
    'heart_rate': heartRate,
    'hrv': hrv,
    'spo2': spo2,
    'temperature': temperature,
    'activity': activity.jsonValue,
  };

  @override
  bool operator ==(Object other) =>
      other is VitalReading &&
      other.timestamp == timestamp &&
      other.heartRate == heartRate &&
      other.hrv == hrv &&
      other.spo2 == spo2 &&
      other.temperature == temperature &&
      other.activity == activity;

  @override
  int get hashCode =>
      Object.hash(timestamp, heartRate, hrv, spo2, temperature, activity);

  @override
  String toString() => 'VitalReading(${toJson()})';
}
