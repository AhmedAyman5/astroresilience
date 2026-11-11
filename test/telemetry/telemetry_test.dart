import 'dart:math';

import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/core/models/scenario.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:astroresilience/layers/engine/edge_engine.dart';
import 'package:astroresilience/layers/nutrition/energy_balance_service.dart';
import 'package:astroresilience/layers/telemetry/replay_parser.dart';
import 'package:astroresilience/layers/telemetry/scenario_profiles.dart';
import 'package:astroresilience/layers/telemetry/simulated_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const interval = Duration(seconds: 5);

/// Runs simulator → energy → engine for [seconds] of simulated time and
/// returns every engine result.
List<EngineResult> runScenario(Scenario scenario, int seconds, int seed) {
  final sim = SimulatedSource(random: Random(seed));
  final energy = EnergyBalanceService();
  final engine = EdgeEngine();
  final results = <EngineResult>[];
  // 1 minute of nominal first, so the baseline can learn.
  for (var i = 0; i < 12; i++) {
    final r = sim.next(t0.add(interval * i), interval);
    energy.recordReading(r, interval);
    results.add(engine.process(r, energyDeficitKcal: energy.deficitKcal));
  }
  sim.scenario = scenario;
  final mealsEaten = !ScenarioProfiles.of(scenario).mealsSkipped;
  final steps = seconds ~/ interval.inSeconds;
  for (var i = 12; i < 12 + steps; i++) {
    final r = sim.next(t0.add(interval * i), interval);
    energy.recordReading(r, interval, scheduledMealsEaten: mealsEaten);
    results.add(engine.process(r, energyDeficitKcal: energy.deficitKcal));
  }
  return results;
}

void main() {
  group('VitalReading', () {
    test('JSON uses the exact keys from the spec', () {
      const json = {
        'timestamp': '2026-11-14T10:30:00',
        'heart_rate': 78,
        'hrv': 42,
        'spo2': 97,
        'temperature': 36.6,
        'activity': 'low',
      };
      final r = VitalReading.fromJson(json);
      expect(r.heartRate, 78);
      expect(r.activity, ActivityLevel.low);
      expect(r.toJson(), json);
    });
  });

  group('SimulatedSource', () {
    test('Nominal values stay realistic and bounded', () {
      final sim = SimulatedSource(random: Random(1));
      for (var i = 0; i < 500; i++) {
        final r = sim.next(t0.add(interval * i), interval);
        expect(r.heartRate, inInclusiveRange(55, 100));
        expect(r.hrv, inInclusiveRange(40, 65));
        expect(r.spo2, inInclusiveRange(96, 100));
        expect(r.temperature, inInclusiveRange(36.3, 36.9));
      }
    });

    test('Scenario change drifts gradually (no jump)', () {
      final sim = SimulatedSource(random: Random(2));
      for (var i = 0; i < 12; i++) {
        sim.next(t0, interval);
      }
      sim.scenario = Scenario.hypoxiaEvent;
      final first = sim.next(t0, interval);
      expect(first.spo2, greaterThanOrEqualTo(96)); // still near normal
      late VitalReading r;
      for (var i = 0; i < 24; i++) {
        r = sim.next(t0, interval); // +2 minutes
      }
      expect(r.spo2, lessThanOrEqualTo(90)); // arrived at the event
    });

    test('Heart rate follows activity', () {
      final sim = SimulatedSource(random: Random(3));
      sim.scenario = Scenario.fatigueOnset;
      late VitalReading r;
      for (var i = 0; i < 40; i++) {
        r = sim.next(t0, interval);
      }
      expect(r.activity, ActivityLevel.high);
      expect(r.heartRate, greaterThan(110));
    });
  });

  group('Scenarios end-to-end (simulator → engine)', () {
    const expected = {
      Scenario.fatigueOnset: RiskType.fatigue,
      Scenario.hypoxiaEvent: RiskType.hypoxia,
      Scenario.thermalStress: RiskType.thermalStress,
      Scenario.nutritionDeficit: RiskType.nutritionDeficit,
    };
    for (final entry in expected.entries) {
      test('${entry.key.code} triggers ${entry.value.code}', () {
        for (final seed in [1, 2, 3]) {
          final results = runScenario(entry.key, 180, seed);
          final last = results.last;
          expect(
            last.status,
            isNot(RiskStatus.normal),
            reason: 'seed $seed',
          );
          expect(last.topPrediction?.type, entry.value, reason: 'seed $seed');
        }
      });
    }

    test('HYPOXIA_EVENT is predicted (WATCH) before the warning', () {
      final results = runScenario(Scenario.hypoxiaEvent, 120, 4);
      final severities = [
        for (final r in results)
          for (final p in r.predictions)
            if (p.type == RiskType.hypoxia) p.severity,
      ];
      expect(severities.first, PredictionSeverity.watch);
      expect(severities, contains(PredictionSeverity.critical));
    });

    test('NOMINAL and RECOVERY never raise a warning (no false alarms)', () {
      for (final scenario in [Scenario.nominal, Scenario.recovery]) {
        for (final seed in [1, 2, 3, 4, 5]) {
          final results = runScenario(scenario, 600, seed);
          for (final r in results) {
            expect(
              r.status,
              RiskStatus.normal,
              reason: '${scenario.code} seed $seed: ${r.toJson()}',
            );
          }
        }
      }
    });
  });

  group('EnergyBalanceService', () {
    test('Rest is covered by the mission menu; exercise builds a deficit', () {
      final energy = EnergyBalanceService();
      energy.recordReading(reading(0), interval);
      expect(energy.deficitKcal, 0);

      // 5 s × 60 = 5 mission minutes × (6.0 − 2.0) kcal = 20 kcal.
      energy.recordReading(
        reading(1, activity: ActivityLevel.high),
        interval,
      );
      expect(energy.deficitKcal, closeTo(20, 1e-9));
    });

    test('Skipped meals: the whole burn becomes deficit', () {
      final energy = EnergyBalanceService();
      // 5 mission minutes × 1.2 kcal at rest.
      energy.recordReading(reading(0), interval, scheduledMealsEaten: false);
      expect(energy.deficitKcal, closeTo(6, 1e-9));
    });

    test('Logged intake reduces the deficit, never below 0', () {
      final energy = EnergyBalanceService();
      for (var i = 0; i < 10; i++) {
        energy.recordReading(
          reading(i, activity: ActivityLevel.high),
          interval,
        );
      }
      expect(energy.deficitKcal, closeTo(200, 1e-9));
      energy.addIntake(150);
      expect(energy.deficitKcal, closeTo(50, 1e-9));
      energy.addIntake(1000);
      expect(energy.deficitKcal, 0);
      expect(energy.totalIntakeKcal, 1150);
    });
  });

  group('ReplayParser (tolerant)', () {
    test('JSON array: good rows kept, bad rows skipped', () {
      const content = '''[
        {"timestamp":"2026-11-14T10:30:00","heart_rate":78,"hrv":42,"spo2":97,"temperature":36.6,"activity":"low"},
        {"timestamp":"2026-11-14T10:31:00","heart_rate":"oops","hrv":42,"spo2":97,"temperature":36.6},
        {"timestamp":"2026-11-14T10:32:00","heart_rate":80,"hrv":40,"spo2":97},
        {"timestamp":"2026-11-14T10:33:00","heart_rate":500,"hrv":40,"spo2":97,"temperature":36.6},
        "not an object",
        {"HR":81,"RMSSD":39,"SpO2":0.96,"Skin Temp":98.2,"activity":"vigorous"}
      ]''';
      final result = ReplayParser.parse(content);
      expect(result.readings.length, 2);
      expect(result.skipped, 4);
      final mapped = result.readings.last;
      expect(mapped.heartRate, 81);
      expect(mapped.hrv, 39);
      expect(mapped.spo2, 96); // fraction → percent
      expect(mapped.temperature, 36.8); // °F → °C
      expect(mapped.activity, ActivityLevel.high);
    });

    test('JSON object with a "readings" array', () {
      const content =
          '{"readings":[{"heart_rate":70,"hrv":50,"spo2":98,"temperature":36.5}]}';
      final result = ReplayParser.parse(content);
      expect(result.readings.single.activity, ActivityLevel.low);
    });

    test('CSV with semicolons, aliases, quotes and comments', () {
      const content = '''
# exported from a NASA dataset
Time;Pulse;HRV (ms);SpO2 %;Temp C;Activity Level
2026-11-14 10:30:00;72;48;98;36.7;0
2026-11-14 10:31:00;;48;98;36.7;0
"2026-11-14 10:32:00";95;35;97;37.1;4.5
''';
      final result = ReplayParser.parse(content);
      expect(result.readings.length, 2);
      expect(result.skipped, 1);
      expect(result.readings.first.heartRate, 72);
      expect(result.readings.last.activity, ActivityLevel.moderate); // METs
      expect(result.readings.last.timestamp.minute, 32);
    });

    test('Garbage input gives no readings instead of crashing', () {
      expect(ReplayParser.parse('[not json').readings, isEmpty);
      expect(ReplayParser.parse('').readings, isEmpty);
      expect(ReplayParser.parse('a,b\n1,2').readings, isEmpty);
    });
  });
}
