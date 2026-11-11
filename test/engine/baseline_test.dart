import 'package:astroresilience/core/constants/engine_constants.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:astroresilience/layers/engine/adaptive_baseline.dart';
import 'package:astroresilience/layers/engine/edge_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Adaptive personal baseline (EMA)', () {
    test('Calm readings pull the baseline toward this astronaut', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      for (var i = 0; i < 40; i++) {
        expect(b.update(reading(i, hr: 62, hrv: 40)), isTrue);
      }
      expect(b.hrv, closeTo(40, 1.0));
      expect(b.heartRate, closeTo(62, 1.0));
    });

    test('Warm-up learns fast (30%), then slowly (5%)', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      b.update(reading(0, hrv: 60));
      expect(b.hrv, closeTo(50 + 0.3 * 10, 1e-9));

      final warm = AdaptiveBaseline(heartRate: 70, hrv: 50);
      for (var i = 0; i < EngineConstants.baselineWarmupReadings; i++) {
        warm.update(reading(i, hrv: 50));
      }
      expect(warm.isWarmingUp, isFalse);
      warm.update(reading(9, hrv: 60));
      expect(warm.hrv, closeTo(50 + 0.05 * 10, 1e-9));
    });

    test('Does NOT learn from exercise, low SpO2, fever or racing heart', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      expect(b.update(reading(0, activity: ActivityLevel.high)), isFalse);
      expect(b.update(reading(1, spo2: 91)), isFalse);
      expect(b.update(reading(2, temp: 37.8)), isFalse);
      expect(b.update(reading(3, hr: 110)), isFalse);
      expect(b.hrv, 50);
      expect(b.heartRate, 70);
    });

    test('After warm-up, a big HRV drop is not learned as "normal"', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      for (var i = 0; i < EngineConstants.baselineWarmupReadings; i++) {
        b.update(reading(i));
      }
      // HRV 35 = 30% below baseline: a warning sign, not a new normal.
      expect(b.update(reading(10, hrv: 35)), isFalse);
      expect(b.hrv, closeTo(50, 1e-9));
    });

    test('hrvDrop is relative to the baseline', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      expect(b.hrvDrop(40), closeTo(0.20, 1e-9));
      expect(b.hrvDrop(60), closeTo(-0.20, 1e-9));
    });

    test('Engine reports learning and personalises the HRV alert', () {
      // Astronaut whose normal HRV is 38 ms (lower than the generic seed).
      final engine = EdgeEngine();
      final r = feed(engine, 40, (i) => reading(i, hr: 64, hrv: 38));
      expect(r.baselineUpdated, isTrue);
      expect(r.baselineHrv, closeTo(38, 1.5));
      // 38 ms is normal for THIS astronaut: no HRV-based risk.
      expect(r.predictions, isEmpty);
    });

    test('reset() goes back to the seed values', () {
      final b = AdaptiveBaseline(heartRate: 70, hrv: 50);
      b.update(reading(0, hrv: 60));
      b.reset();
      expect(b.hrv, 50);
      expect(b.calmReadings, 0);
    });
  });
}
