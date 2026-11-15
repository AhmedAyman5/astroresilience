import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astroresilience/core/constants/nutrition_constants.dart';
import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/core/models/food.dart';
import 'package:astroresilience/core/models/log_entry.dart';
import 'package:astroresilience/core/models/scenario.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:astroresilience/layers/engine/engine_controller.dart';
import 'package:astroresilience/layers/log/mission_log_controller.dart';
import 'package:astroresilience/layers/nutrition/action_advisor.dart';
import 'package:astroresilience/layers/nutrition/energy_balance_service.dart';
import 'package:astroresilience/layers/nutrition/food_recommender.dart';
import 'package:astroresilience/layers/nutrition/nutrition_controller.dart';
import 'package:astroresilience/layers/security/log_store.dart';
import 'package:astroresilience/layers/security/security_service.dart';
import 'package:astroresilience/layers/telemetry/telemetry_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real bundled database, read straight from the file.
List<Food> loadFoods() {
  final list = jsonDecode(File('assets/data/foods.json').readAsStringSync());
  return (list as List)
      .map((e) => Food.fromJson(e as Map<String, dynamic>))
      .toList();
}

RiskPrediction pred(
  RiskType type, [
  PredictionSeverity severity = PredictionSeverity.warning,
]) => RiskPrediction(
  type: type,
  severity: severity,
  confidence: 80,
  trend: RiskTrend.stable,
  intensity: 0.6,
  why: const ['test'],
);

/// Everything the meal loop needs, without timers or plugins.
class LoopHarness {
  LoopHarness(List<Food> foods) {
    telemetry = TelemetryController(autoStart: false);
    energy = EnergyBalanceService();
    engine = EngineController(telemetry: telemetry, energy: energy);
    store = InMemoryLogStore();
    log = MissionLogController(
      store: store,
      engine: engine,
      telemetry: telemetry,
    );
    nutrition = NutritionController(
      engine: engine,
      log: log,
      energy: energy,
      loadFoods: () async => foods,
    );
  }

  late final TelemetryController telemetry;
  late final EnergyBalanceService energy;
  late final EngineController engine;
  late final InMemoryLogStore store;
  late final MissionLogController log;
  late final NutritionController nutrition;

  Future<void> ready() async {
    await log.ready;
    await nutrition.ready;
  }

  /// Builds an energy deficit: hard work with meals skipped.
  void buildDeficit() {
    final r = VitalReading(
      timestamp: DateTime(2026, 11, 14, 10),
      heartRate: 140,
      hrv: 30,
      spo2: 97,
      temperature: 36.8,
      activity: ActivityLevel.high,
    );
    for (var i = 0; i < 50; i++) {
      energy.recordReading(
        r,
        const Duration(seconds: 5),
        scheduledMealsEaten: false,
      );
    }
  }

  void dispose() {
    nutrition.dispose();
    log.dispose();
    engine.dispose();
    telemetry.dispose();
  }
}

void main() {
  final foods = loadFoods();
  const recommender = FoodRecommender();

  group('Food database', () {
    test('About 25 foods with the required fields', () {
      expect(foods.length, inInclusiveRange(22, 30));
      expect(foods.map((f) => f.id).toSet().length, foods.length);
      for (final f in foods) {
        expect(f.kcal, greaterThan(0));
        expect(Food.fromJson(f.toJson()).toJson(), f.toJson());
      }
    });

    test('Every tag of the risk→tags mapping is on at least 3 foods', () {
      final tags = NutritionConstants.riskTagWeights.values
          .expand((m) => m.keys)
          .toSet();
      for (final tag in tags) {
        expect(
          foods.where((f) => f.hasTag(tag)).length,
          greaterThanOrEqualTo(3),
          reason: tag,
        );
      }
    });
  });

  group('FoodRecommender', () {
    test('Right foods first for every risk', () {
      for (final risk in RiskType.values) {
        final ranked = recommender.rank(risk, foods, const {});
        expect(ranked, isNotEmpty, reason: risk.code);
        // The best food has every preferred tag of that risk.
        expect(ranked.first.tagScore, 1.0, reason: risk.code);
        for (final tag in NutritionConstants.riskTagWeights[risk]!.keys) {
          expect(ranked.first.food.hasTag(tag), isTrue, reason: risk.code);
        }
        // Sorted best first.
        for (var i = 1; i < ranked.length; i++) {
          expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
        }
        expect(ranked.first.reasons.first, startsWith('Matches: '));
      }
    });

    test('Fatigue → high protein + quick energy food ranks first', () {
      final top = recommender.rank(RiskType.fatigue, foods, const {}).first;
      expect(top.food.hasTag('high_protein'), isTrue);
      expect(top.food.hasTag('quick_energy'), isTrue);
      expect(top.reasons.first, 'Matches: high_protein, quick_energy');
    });

    test('A food eaten at 25% several times drops below a similar one', () {
      // Tomato soup (f14) and vegetable broth (f15) both fully match
      // thermal stress. Without history, f14 wins the tie (id order).
      final before = recommender.rank(RiskType.thermalStress, foods, const {});
      final ids = before.map((r) => r.food.id).toList();
      expect(ids.indexOf('f14'), lessThan(ids.indexOf('f15')));

      final prefs = FoodRecommender.buildPreferences([
        for (var i = 0; i < 3; i++) (foodId: 'f14', consumptionPct: 25),
      ]);
      expect(prefs['f14']!.averagePct, 25);
      expect(recommender.preferenceFactor(prefs['f14']), closeTo(0.625, 1e-9));

      final after = recommender.rank(RiskType.thermalStress, foods, prefs);
      final idsAfter = after.map((r) => r.food.id).toList();
      expect(idsAfter.indexOf('f14'), greaterThan(idsAfter.indexOf('f15')));
      final soup = after.firstWhere((r) => r.food.id == 'f14');
      expect(soup.reasons, contains('Ranked lower: you usually eat about 25%'));
    });

    test('Fully eaten food keeps its rank (factor 1.0)', () {
      final prefs = FoodRecommender.buildPreferences([
        (foodId: 'f14', consumptionPct: 100),
      ]);
      expect(recommender.preferenceFactor(prefs['f14']), 1.0);
      expect(recommender.preferenceFactor(null), 1.0);
    });

    test('No prediction → routine action only', () {
      final plan = recommender.plan(const [], foods, const {});
      expect(plan.hasActiveRisk, isFalse);
      expect(plan.recommendations, isEmpty);
      expect(plan.routineAction, same(ActionAdvisor.routine));
    });

    test('Max 2 recommendations, worst first, 3 foods + an action each', () {
      final plan = recommender.plan(
        [
          pred(RiskType.hypoxia, PredictionSeverity.critical),
          pred(RiskType.fatigue),
          pred(RiskType.thermalStress, PredictionSeverity.watch),
        ],
        foods,
        const {},
      );
      expect(plan.recommendations.length, 2);
      expect(plan.recommendations.first.prediction.type, RiskType.hypoxia);
      for (final r in plan.recommendations) {
        expect(r.foods.length, NutritionConstants.foodsPerRecommendation);
        expect(r.action.title, isNotEmpty);
      }
    });

    test('Ties are stable: same order whatever the input order', () {
      final a = recommender
          .rank(RiskType.physiologicalStress, foods, const {})
          .map((r) => r.food.id)
          .toList();
      final b = recommender
          .rank(RiskType.physiologicalStress, foods.reversed.toList(), const {})
          .map((r) => r.food.id)
          .toList();
      expect(b, a);
    });
  });

  group('Meal logging loop', () {
    test('Logging a meal lowers the deficit, adds a log entry and '
        'updates preferences', () async {
      final h = LoopHarness(foods);
      await h.ready();
      h.buildDeficit();
      final before = h.energy.deficitKcal;
      expect(before, greaterThan(1000));

      final soup = foods.firstWhere((f) => f.id == 'f14');
      final result = h.nutrition.logMeal(
        soup,
        50,
        answeredRisk: RiskType.thermalStress,
      );
      expect(result.kcalEaten, soup.kcal * 0.5);
      expect(h.energy.deficitKcal, closeTo(before - soup.kcal * 0.5, 1e-6));

      final meals = h.log.mealEntries;
      expect(meals.length, 1);
      expect(meals.first.type, LogEntryType.meal);
      expect(meals.first.data!['consumption_pct'], 50);
      expect(meals.first.data!['risk'], 'THERMAL_STRESS');
      expect(await h.store.count(), 1);

      expect(h.nutrition.preferenceOf('f14')!.averagePct, 50);
      h.nutrition.logMeal(soup, 25);
      expect(h.nutrition.preferenceOf('f14')!.averagePct, 37.5);
      h.dispose();
    });

    test('Test meal goes through the same path but teaches nothing', () async {
      final h = LoopHarness(foods);
      await h.ready();
      h.buildDeficit();
      final before = h.energy.deficitKcal;
      final r = h.nutrition.logTestMeal();
      expect(r.foodName, NutritionConstants.testMealName);
      expect(
        h.energy.deficitKcal,
        closeTo(before - NutritionConstants.testMealKcal, 1e-6),
      );
      expect(h.log.mealEntries.single.title, startsWith('Test meal'));
      expect(h.nutrition.preferences, isEmpty);
      h.dispose();
    });

    test('Reset session keeps the log and meal history', () async {
      final h = LoopHarness(foods);
      await h.ready();
      h.nutrition.logMeal(foods.first, 75);
      h.telemetry.resetSession();
      expect(h.log.mealEntries.length, 1);
      expect(h.log.entries.where((e) => e.title == 'Session reset').length, 1);
      expect(h.nutrition.preferenceOf(foods.first.id), isNotNull);
      h.dispose();
    });

    test('Stored log is loaded back on start (survives a restart)', () async {
      final store = InMemoryLogStore();
      final telemetry = TelemetryController(autoStart: false);
      final energy = EnergyBalanceService();
      final engine = EngineController(telemetry: telemetry, energy: energy);
      final first = MissionLogController(
        store: store,
        engine: engine,
        telemetry: telemetry,
      );
      await first.ready;
      first.recordMeal(
        foodId: 'f01',
        foodName: 'Scrambled eggs',
        consumptionPct: 100,
        kcalEaten: 220,
      );
      first.dispose();
      await Future<void>.delayed(Duration.zero);

      final second = MissionLogController(
        store: store,
        engine: engine,
        telemetry: telemetry,
      );
      await second.ready;
      expect(second.mealEntries.single.data!['food_id'], 'f01');
      second.dispose();
      engine.dispose();
      telemetry.dispose();
    });
  });

  group('Security (Layer 5)', () {
    test('Wipe empties the log, meal history and preferences', () async {
      final h = LoopHarness(foods);
      await h.ready();
      final security = SecurityService(store: h.store, log: h.log);
      expect(security.mode, StorageMode.memoryOnly);
      expect(security.storageLabel, 'MEMORY ONLY');

      final soup = foods.firstWhere((f) => f.id == 'f14');
      h.nutrition.logMeal(soup, 25);
      h.nutrition.logMeal(soup, 25);
      h.telemetry.setScenario(Scenario.hypoxiaEvent); // a system entry
      expect(h.log.length, 3);
      expect(h.nutrition.preferenceOf('f14'), isNotNull);
      expect(await h.store.count(), 3);

      await security.wipeLocalData();
      expect(h.log.length, 0);
      expect(h.log.mealEntries, isEmpty);
      expect(h.nutrition.preferences, isEmpty);
      expect(await h.store.count(), 0);
      expect(security.storedCount, 0);

      // The app keeps working after a wipe.
      h.nutrition.logMeal(soup, 100);
      expect(h.log.mealEntries.length, 1);
      security.dispose();
      h.dispose();
    });

    test('Store that fails to open falls back to memory only', () async {
      final opened = await openLogStore(
        opener: () async => throw StateError('no secure storage'),
      );
      expect(opened.store, isA<InMemoryLogStore>());
      expect(opened.error, contains('no secure storage'));
    });

    test('Store that hangs falls back after the timeout', () async {
      final opened = await openLogStore(
        timeout: const Duration(milliseconds: 50),
        opener: () => Completer<LogStore>().future,
      );
      expect(opened.store.isPersistent, isFalse);
    });
  });
}
