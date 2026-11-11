import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/layers/engine/edge_engine.dart';
import 'package:astroresilience/layers/engine/risk_scoring.dart';
import 'package:astroresilience/layers/engine/trend_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final times = [
    for (var i = 0; i < 12; i++) t0.add(Duration(seconds: 5 * i)),
  ];

  group('Trend detection (slope over the window)', () {
    test('Falling SpO2 = RISING hypoxia risk', () {
      final values = [for (var i = 0; i < 12; i++) 98.0 - 0.3 * i];
      final t = TrendAnalyzer.analyze(times, values, EdgeEngine.spo2Scale);
      expect(t.trend, RiskTrend.rising);
      expect(t.slopePerMinute, closeTo(-3.6, 0.01)); // −0.3 per 5 s
    });

    test('Rising SpO2 = FALLING hypoxia risk', () {
      final values = [for (var i = 0; i < 12; i++) 90.0 + 0.3 * i];
      final t = TrendAnalyzer.analyze(times, values, EdgeEngine.spo2Scale);
      expect(t.trend, RiskTrend.falling);
    });

    test('Flat or noisy series = STABLE', () {
      final flat = List<double>.filled(12, 97);
      expect(
        TrendAnalyzer.analyze(times, flat, EdgeEngine.spo2Scale).trend,
        RiskTrend.stable,
      );
      final noisy = [for (var i = 0; i < 12; i++) i.isEven ? 97.0 : 98.0];
      expect(
        TrendAnalyzer.analyze(times, noisy, EdgeEngine.spo2Scale).trend,
        RiskTrend.stable,
      );
    });

    test('Fewer than 4 readings = STABLE (not enough data)', () {
      final t = TrendAnalyzer.analyze(
        times.sublist(0, 3),
        [98, 95, 92],
        EdgeEngine.spo2Scale,
      );
      expect(t.trend, RiskTrend.stable);
    });

    test('minutesTo: time to reach a threshold at the current slope', () {
      expect(TrendAnalyzer.minutesTo(96, 94, -1), 2);
      expect(TrendAnalyzer.minutesTo(96, 94, -10), 1); // at least 1
      expect(TrendAnalyzer.minutesTo(96, 94, 1), isNull); // moving away
    });

    test('Engine PREDICTS thermal stress before the threshold (WATCH)', () {
      // Temperature climbing 0.06 °C every 5 s, still under 37.5.
      final r = feed(
        engineWithBaseline(),
        12,
        (i) => reading(i, temp: 36.8 + 0.06 * i),
      );
      final p = prediction(r, RiskType.thermalStress)!;
      expect(p.severity, PredictionSeverity.watch);
      expect(p.trend, RiskTrend.rising);
      expect(p.minutesToThreshold, isNotNull);
      expect(p.why.join(' '), contains('warning threshold is reached'));
      expect(r.status, RiskStatus.normal);
    });
  });

  group('Severity scale', () {
    test('Higher-is-worse metric (temperature)', () {
      final s = EdgeEngine.tempScale;
      expect(s.level(36.6), 0);
      expect(s.level(37.5), closeTo(0.5, 1e-9));
      expect(s.level(38.0), closeTo(1.0, 1e-9));
      expect(s.level(45), 1.5); // capped
    });

    test('Lower-is-worse metric (SpO2)', () {
      final s = EdgeEngine.spo2Scale;
      expect(s.higherIsWorse, isFalse);
      expect(s.level(98), 0);
      expect(s.level(94), closeTo(0.5, 1e-9));
      expect(s.level(92), closeTo(0.75, 1e-9));
      expect(s.level(90), closeTo(1.0, 1e-9));
    });
  });

  group('Status boundaries and risk score', () {
    test('Score bands: 0–39 NORMAL, 40–69 WARNING, 70–100 CRITICAL', () {
      expect(RiskScoring.statusForScore(0), RiskStatus.normal);
      expect(RiskScoring.statusForScore(39), RiskStatus.normal);
      expect(RiskScoring.statusForScore(40), RiskStatus.warning);
      expect(RiskScoring.statusForScore(69), RiskStatus.warning);
      expect(RiskScoring.statusForScore(70), RiskStatus.critical);
      expect(RiskScoring.statusForScore(100), RiskStatus.critical);
    });

    test('Points line up with the bands', () {
      expect(RiskScoring.points(0), 0);
      expect(RiskScoring.points(0.5), 40);
      expect(RiskScoring.points(1.0), 70);
      expect(RiskScoring.points(1.5), 100);
    });

    test('One warning-level risk alone gives a WARNING score', () {
      final score = RiskScoring.combinedScore({RiskType.hypoxia: 0.5});
      expect(RiskScoring.statusForScore(score), RiskStatus.warning);
    });

    test('One critical risk alone gives a CRITICAL score', () {
      final score = RiskScoring.combinedScore({RiskType.nutritionDeficit: 1.0});
      expect(score, 70);
      expect(RiskScoring.statusForScore(score), RiskStatus.critical);
    });

    test('Other risks add on top, weighted by danger', () {
      final base = RiskScoring.combinedScore({RiskType.fatigue: 1.0});
      final plusHypoxia = RiskScoring.combinedScore({
        RiskType.fatigue: 1.0,
        RiskType.hypoxia: 0.5,
      });
      final plusNutrition = RiskScoring.combinedScore({
        RiskType.fatigue: 1.0,
        RiskType.nutritionDeficit: 0.5,
      });
      expect(plusHypoxia, greaterThan(base));
      // Hypoxia weighs more than a nutrition deficit.
      expect(plusHypoxia, greaterThan(plusNutrition));
      expect(RiskScoring.combinedScore({RiskType.hypoxia: 9}), 100);
    });

    test('Severity from level', () {
      expect(RiskScoring.severityForLevel(0.3), PredictionSeverity.watch);
      expect(RiskScoring.severityForLevel(0.5), PredictionSeverity.warning);
      expect(RiskScoring.severityForLevel(1.0), PredictionSeverity.critical);
    });
  });
}
