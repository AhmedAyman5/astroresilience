import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// One group per risk rule of the Edge AI Engine (CLAUDE.md section 4).
void main() {
  test('Calm baseline readings: no predictions, NORMAL status', () {
    final r = feed(engineWithBaseline(), 12, (i) => reading(i));
    expect(r.predictions, isEmpty);
    expect(r.status, RiskStatus.normal);
    expect(r.riskScore, lessThan(40));
  });

  group('FATIGUE (low HRV + high HR + high activity)', () {
    test('all three signals → CRITICAL fatigue', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 125, hrv: 30, activity: ActivityLevel.high),
      );
      final p = prediction(r, RiskType.fatigue)!;
      expect(p.severity, PredictionSeverity.critical);
      expect(r.status, RiskStatus.critical);
      expect(p.why.join(' '), contains('below your baseline'));
      expect(p.why.join(' '), contains('High activity'));
      expect(p.confidence, greaterThan(90));
    });

    test('only high HR (no sustained high activity) → one notch lower', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 115, hrv: 30, activity: ActivityLevel.moderate),
      );
      expect(
        prediction(r, RiskType.fatigue)!.severity,
        PredictionSeverity.warning,
      );
    });

    test('low HRV alone at rest is not fatigue', () {
      final r = feed(engineWithBaseline(), 12, (i) => reading(i, hrv: 30));
      expect(prediction(r, RiskType.fatigue), isNull);
    });
  });

  group('HYPOXIA (SpO2 under threshold)', () {
    test('SpO2 93 → WARNING', () {
      final r = feed(engineWithBaseline(), 12, (i) => reading(i, spo2: 93));
      expect(
        prediction(r, RiskType.hypoxia)!.severity,
        PredictionSeverity.warning,
      );
      expect(r.status, RiskStatus.warning);
    });

    test('SpO2 89 → CRITICAL, compensation mentioned', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, spo2: 89, hr: 90),
      );
      final p = prediction(r, RiskType.hypoxia)!;
      expect(p.severity, PredictionSeverity.critical);
      expect(r.status, RiskStatus.critical);
      expect(p.why.join(' '), contains('compensating'));
    });

    test('SpO2 95 (above warning, stable) → no prediction', () {
      final r = feed(engineWithBaseline(), 12, (i) => reading(i, spo2: 95));
      expect(prediction(r, RiskType.hypoxia), isNull);
    });
  });

  group('THERMAL_STRESS (sustained high temperature)', () {
    test('3 readings over 38.0 → CRITICAL', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, temp: i >= 9 ? 38.2 : 36.6),
      );
      expect(
        prediction(r, RiskType.thermalStress)!.severity,
        PredictionSeverity.critical,
      );
    });

    test('only 2 hot readings is not sustained → no warning', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, temp: i >= 10 ? 38.2 : 36.6),
      );
      final p = prediction(r, RiskType.thermalStress);
      expect(p == null || p.severity == PredictionSeverity.watch, isTrue);
      expect(r.status, RiskStatus.normal);
    });

    test('37.7 sustained → WARNING', () {
      final r = feed(engineWithBaseline(), 12, (i) => reading(i, temp: 37.7));
      expect(
        prediction(r, RiskType.thermalStress)!.severity,
        PredictionSeverity.warning,
      );
    });
  });

  group('PHYSIOLOGICAL_STRESS (high HR at low activity + low HRV)', () {
    test('HR 125 at rest + low HRV → CRITICAL', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 125, hrv: 30),
      );
      final p = prediction(r, RiskType.physiologicalStress)!;
      expect(p.severity, PredictionSeverity.critical);
      expect(p.why.join(' '), contains('at rest'));
    });

    test('HR 125 at rest with normal HRV → one notch lower (WARNING)', () {
      final r = feed(engineWithBaseline(), 12, (i) => reading(i, hr: 125));
      expect(
        prediction(r, RiskType.physiologicalStress)!.severity,
        PredictionSeverity.warning,
      );
    });

    test('High HR during high activity is not physiological stress', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 125, activity: ActivityLevel.high),
      );
      expect(prediction(r, RiskType.physiologicalStress), isNull);
    });
  });

  group('NUTRITION_DEFICIT (energy deficit + fatigue markers)', () {
    // Moderate activity so the readings are not "calm" (baseline stays put).
    test('950 kcal deficit + HRV marker → CRITICAL', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 90, hrv: 42, activity: ActivityLevel.moderate),
        deficit: 950,
      );
      final p = prediction(r, RiskType.nutritionDeficit)!;
      expect(p.severity, PredictionSeverity.critical);
      expect(p.why.join(' '), contains('Fatigue marker'));
    });

    test('950 kcal deficit without fatigue markers → WARNING', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hr: 90, activity: ActivityLevel.moderate),
        deficit: 950,
      );
      expect(
        prediction(r, RiskType.nutritionDeficit)!.severity,
        PredictionSeverity.warning,
      );
    });

    test('small deficit → nothing', () {
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, hrv: 42, activity: ActivityLevel.moderate),
        deficit: 150,
      );
      expect(prediction(r, RiskType.nutritionDeficit), isNull);
    });
  });

  test('Predictions are sorted from most to least serious', () {
    final r = feed(
      engineWithBaseline(),
      12,
      (i) => reading(i, spo2: 89, temp: 37.7),
    );
    expect(r.predictions.first.type, RiskType.hypoxia);
    expect(r.predictions.map((p) => p.type), contains(RiskType.thermalStress));
    // Two risks at once score higher than hypoxia alone.
    final alone = feed(engineWithBaseline(), 12, (i) => reading(i, spo2: 89));
    expect(r.riskScore, greaterThan(alone.riskScore));
  });

  test('EngineResult survives a JSON round trip', () {
    final r = feed(engineWithBaseline(), 12, (i) => reading(i, spo2: 89));
    final copy = EngineResult.fromJson(r.toJson());
    expect(copy.riskScore, r.riskScore);
    expect(copy.status, r.status);
    expect(copy.predictions.first.type, RiskType.hypoxia);
    expect(copy.reading, r.reading);
  });
}
