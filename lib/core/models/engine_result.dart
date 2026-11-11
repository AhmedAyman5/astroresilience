import 'package:flutter/foundation.dart';

import '../utils/time_format.dart';
import 'vital_reading.dart';

/// The 5 health risks the Edge AI Engine can predict.
enum RiskType {
  fatigue,
  physiologicalStress,
  hypoxia,
  thermalStress,
  nutritionDeficit;

  String get code => switch (this) {
    RiskType.fatigue => 'FATIGUE',
    RiskType.physiologicalStress => 'PHYSIOLOGICAL_STRESS',
    RiskType.hypoxia => 'HYPOXIA',
    RiskType.thermalStress => 'THERMAL_STRESS',
    RiskType.nutritionDeficit => 'NUTRITION_DEFICIT',
  };

  String get label => switch (this) {
    RiskType.fatigue => 'Fatigue',
    RiskType.physiologicalStress => 'Physiological stress',
    RiskType.hypoxia => 'Hypoxia',
    RiskType.thermalStress => 'Thermal stress',
    RiskType.nutritionDeficit => 'Nutrition deficit',
  };

  static RiskType fromCode(String code) =>
      RiskType.values.firstWhere((t) => t.code == code);
}

/// Overall astronaut status, derived from the risk score.
enum RiskStatus {
  normal,
  warning,
  critical;

  String get code => name.toUpperCase();
  String get label => switch (this) {
    RiskStatus.normal => 'Normal',
    RiskStatus.warning => 'Warning',
    RiskStatus.critical => 'Critical',
  };

  static RiskStatus fromCode(String code) =>
      RiskStatus.values.firstWhere((s) => s.code == code);
}

/// How serious one prediction is.
/// - watch: threshold NOT reached yet, but the trend is heading there soon
///   (this is the "predict before it happens" part).
/// - warning / critical: the warning / critical threshold is reached.
enum PredictionSeverity {
  watch,
  warning,
  critical;

  String get code => name.toUpperCase();
  String get label => switch (this) {
    PredictionSeverity.watch => 'Watch',
    PredictionSeverity.warning => 'Warning',
    PredictionSeverity.critical => 'Critical',
  };

  static PredictionSeverity fromCode(String code) =>
      PredictionSeverity.values.firstWhere((s) => s.code == code);
}

/// Direction of a RISK over the rolling window (not of the raw number):
/// "rising" means the risk is getting worse — e.g. SpO2 going DOWN makes the
/// hypoxia risk rise.
enum RiskTrend {
  rising,
  stable,
  falling;

  String get code => name.toUpperCase();
  String get label => switch (this) {
    RiskTrend.rising => 'Rising',
    RiskTrend.stable => 'Stable',
    RiskTrend.falling => 'Falling',
  };

  static RiskTrend fromCode(String code) =>
      RiskTrend.values.firstWhere((t) => t.code == code);
}

/// One explainable prediction made by the engine.
@immutable
class RiskPrediction {
  const RiskPrediction({
    required this.type,
    required this.severity,
    required this.confidence,
    required this.trend,
    required this.intensity,
    required this.why,
    this.minutesToThreshold,
  });

  final RiskType type;
  final PredictionSeverity severity;

  /// How sure the engine is, 0–100 %.
  final int confidence;

  final RiskTrend trend;

  /// Estimated minutes until the next threshold (warning, or critical if the
  /// warning is already reached). Only set when the risk is rising.
  final int? minutesToThreshold;

  /// Internal severity on the shared scale: 0 = fine, 0.5 = warning
  /// threshold, 1.0 = critical threshold, up to 1.5 far beyond critical.
  final double intensity;

  /// Plain-English list of the signals that triggered this prediction.
  final List<String> why;

  RiskPrediction copyWith({
    RiskType? type,
    PredictionSeverity? severity,
    int? confidence,
    RiskTrend? trend,
    int? minutesToThreshold,
    double? intensity,
    List<String>? why,
  }) {
    return RiskPrediction(
      type: type ?? this.type,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      trend: trend ?? this.trend,
      minutesToThreshold: minutesToThreshold ?? this.minutesToThreshold,
      intensity: intensity ?? this.intensity,
      why: why ?? this.why,
    );
  }

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      type: RiskType.fromCode(json['type'] as String),
      severity: PredictionSeverity.fromCode(json['severity'] as String),
      confidence: (json['confidence'] as num).round(),
      trend: RiskTrend.fromCode(json['trend'] as String),
      minutesToThreshold: (json['minutes_to_threshold'] as num?)?.round(),
      intensity: (json['intensity'] as num).toDouble(),
      why: (json['why'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.code,
    'severity': severity.code,
    'confidence': confidence,
    'trend': trend.code,
    'minutes_to_threshold': minutesToThreshold,
    'intensity': double.parse(intensity.toStringAsFixed(3)),
    'why': why,
  };
}

/// Everything the engine concluded after one reading.
@immutable
class EngineResult {
  const EngineResult({
    required this.timestamp,
    required this.reading,
    required this.riskScore,
    required this.status,
    required this.predictions,
    required this.baselineHeartRate,
    required this.baselineHrv,
    required this.baselineUpdated,
    required this.energyDeficitKcal,
    required this.windowSize,
  });

  final DateTime timestamp;

  /// The reading that produced this result.
  final VitalReading reading;

  /// Combined risk, 0–100.
  final int riskScore;
  final RiskStatus status;

  /// Sorted from most to least serious.
  final List<RiskPrediction> predictions;

  /// The astronaut's learned personal baseline (adaptive EMA).
  final double baselineHeartRate;
  final double baselineHrv;

  /// True if this reading was calm and therefore used to update the baseline.
  final bool baselineUpdated;

  final double energyDeficitKcal;

  /// How many readings are in the rolling window (max 12).
  final int windowSize;

  /// The most serious prediction, or null if everything is fine.
  RiskPrediction? get topPrediction =>
      predictions.isEmpty ? null : predictions.first;

  EngineResult copyWith({
    DateTime? timestamp,
    VitalReading? reading,
    int? riskScore,
    RiskStatus? status,
    List<RiskPrediction>? predictions,
    double? baselineHeartRate,
    double? baselineHrv,
    bool? baselineUpdated,
    double? energyDeficitKcal,
    int? windowSize,
  }) {
    return EngineResult(
      timestamp: timestamp ?? this.timestamp,
      reading: reading ?? this.reading,
      riskScore: riskScore ?? this.riskScore,
      status: status ?? this.status,
      predictions: predictions ?? this.predictions,
      baselineHeartRate: baselineHeartRate ?? this.baselineHeartRate,
      baselineHrv: baselineHrv ?? this.baselineHrv,
      baselineUpdated: baselineUpdated ?? this.baselineUpdated,
      energyDeficitKcal: energyDeficitKcal ?? this.energyDeficitKcal,
      windowSize: windowSize ?? this.windowSize,
    );
  }

  factory EngineResult.fromJson(Map<String, dynamic> json) {
    return EngineResult(
      timestamp: DateTime.parse(json['timestamp'] as String),
      reading: VitalReading.fromJson(json['reading'] as Map<String, dynamic>),
      riskScore: (json['risk_score'] as num).round(),
      status: RiskStatus.fromCode(json['status'] as String),
      predictions: (json['predictions'] as List)
          .map((p) => RiskPrediction.fromJson(p as Map<String, dynamic>))
          .toList(),
      baselineHeartRate: (json['baseline_heart_rate'] as num).toDouble(),
      baselineHrv: (json['baseline_hrv'] as num).toDouble(),
      baselineUpdated: json['baseline_updated'] as bool,
      energyDeficitKcal: (json['energy_deficit_kcal'] as num).toDouble(),
      windowSize: (json['window_size'] as num).round(),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': TimeFormat.isoSeconds(timestamp),
    'reading': reading.toJson(),
    'risk_score': riskScore,
    'status': status.code,
    'predictions': predictions.map((p) => p.toJson()).toList(),
    'baseline_heart_rate': double.parse(baselineHeartRate.toStringAsFixed(1)),
    'baseline_hrv': double.parse(baselineHrv.toStringAsFixed(1)),
    'baseline_updated': baselineUpdated,
    'energy_deficit_kcal': energyDeficitKcal.round(),
    'window_size': windowSize,
  };
}
