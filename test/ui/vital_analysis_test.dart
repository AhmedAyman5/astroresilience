import 'package:astroresilience/core/models/alert_level.dart';
import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/core/models/vital_kind.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:astroresilience/core/utils/vital_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Vital card status', () {
    VitalRangeStatus status(VitalKind k, List<VitalReading> h) =>
        VitalAnalysis.status(k, h, baselineHrv: 50);

    test('SpO2 uses the average of the last 3 readings', () {
      final h = [
        for (var i = 0; i < 5; i++) reading(i, spo2: 97),
        reading(5, spo2: 92), // one dip alone is not enough
      ];
      expect(status(VitalKind.spo2, h), VitalRangeStatus.inRange);
      h.addAll([reading(6, spo2: 92), reading(7, spo2: 92)]);
      expect(status(VitalKind.spo2, h), VitalRangeStatus.warning);
      h.addAll([for (var i = 8; i < 11; i++) reading(i, spo2: 88)]);
      expect(status(VitalKind.spo2, h), VitalRangeStatus.critical);
    });

    test('High heart rate only counts at low activity', () {
      final exercise = [
        for (var i = 0; i < 3; i++)
          reading(i, hr: 130, activity: ActivityLevel.high),
      ];
      expect(status(VitalKind.heartRate, exercise), VitalRangeStatus.inRange);
      final rest = [for (var i = 0; i < 3; i++) reading(i, hr: 130)];
      expect(status(VitalKind.heartRate, rest), VitalRangeStatus.critical);
    });

    test('HRV is judged against the personal baseline', () {
      // Baseline 50: 38 = 24% drop (warning), 30 = 40% drop (critical).
      expect(
        status(VitalKind.hrv, [for (var i = 0; i < 3; i++) reading(i, hrv: 38)]),
        VitalRangeStatus.warning,
      );
      expect(
        status(VitalKind.hrv, [for (var i = 0; i < 3; i++) reading(i, hrv: 30)]),
        VitalRangeStatus.critical,
      );
    });

    test('Temperature thresholds', () {
      List<VitalReading> t(double v) => [
        for (var i = 0; i < 3; i++) reading(i, temp: v),
      ];
      expect(status(VitalKind.temperature, t(36.8)), VitalRangeStatus.inRange);
      expect(status(VitalKind.temperature, t(37.7)), VitalRangeStatus.warning);
      expect(status(VitalKind.temperature, t(38.3)), VitalRangeStatus.critical);
    });
  });

  test('Trend arrow ignores small noise', () {
    final flat = [for (var i = 0; i < 12; i++) reading(i, hr: 70 + i % 2)];
    expect(
      VitalAnalysis.direction(VitalKind.heartRate, flat),
      ValueDirection.flat,
    );
    final rising = [for (var i = 0; i < 12; i++) reading(i, hr: 70 + i)];
    expect(
      VitalAnalysis.direction(VitalKind.heartRate, rising),
      ValueDirection.up,
    );
  });

  test('Range filter keeps only the last N minutes', () {
    // Readings 5 s apart: 2 minutes = 25 readings (both ends included).
    final h = [for (var i = 0; i < 100; i++) reading(i)];
    expect(VitalAnalysis.inRange(h, const Duration(minutes: 2)).length, 25);
    expect(VitalAnalysis.inRange(h, null).length, 100);
  });

  test('HRV threshold lines follow the learned baseline', () {
    final lines = VitalAnalysis.thresholdLines(VitalKind.hrv, baselineHrv: 60);
    expect(lines.first.value, closeTo(48, 0.001)); // −20%
    expect(lines.last.value, closeTo(39, 0.001)); // −35%
  });

  test('Alert level adds WATCH between NOMINAL and WARNING', () {
    final engine = engineWithBaseline();
    final calm = feed(engine, 12, (i) => reading(i));
    expect(AlertLevel.of(calm), AlertLevel.nominal);
    expect(AlertLevel.of(null), AlertLevel.nominal);

    final watch = calm.copyWith(
      predictions: [
        const RiskPrediction(
          type: RiskType.hypoxia,
          severity: PredictionSeverity.watch,
          confidence: 60,
          trend: RiskTrend.rising,
          intensity: 0.3,
          why: ['SpO2 falling'],
          minutesToThreshold: 4,
        ),
      ],
    );
    expect(AlertLevel.of(watch), AlertLevel.watch);
    expect(
      AlertLevel.of(watch.copyWith(status: RiskStatus.critical)),
      AlertLevel.critical,
    );
  });
}
