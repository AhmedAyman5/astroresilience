import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/nutrition_constants.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/food.dart';
import '../../core/models/log_entry.dart';
import '../engine/engine_controller.dart';
import '../log/mission_log_controller.dart';
import 'energy_balance_service.dart';
import 'food_recommender.dart';

/// Loads the bundled food database once (no network).
Future<List<Food>> loadFoodsFromAssets() async {
  // cache: false — read once per controller; the controller keeps the list.
  final text = await rootBundle.loadString(
    NutritionConstants.foodsAsset,
    cache: false,
  );
  final list = jsonDecode(text) as List;
  return List.unmodifiable(
    list.map((e) => Food.fromJson(e as Map<String, dynamic>)),
  );
}

/// What happened when a meal was logged (the UI shows it in a snackbar).
class MealLogResult {
  const MealLogResult({
    required this.foodName,
    required this.consumptionPct,
    required this.kcalEaten,
    required this.entry,
  });

  final String foodName;
  final int consumptionPct;
  final double kcalEaten;
  final LogEntry entry;
}

/// Layer 3 state: the Predictive Nutrition Loop.
///
/// THE LOOP
/// 1. The engine predicts a risk → [plan] ranks foods for it (+ an action).
/// 2. The astronaut picks a meal and how much they ate (100/75/50/25 %).
/// 3. [logMeal]: kcal × % goes into the energy balance, the meal is written
///    to the (encrypted) Mission Log, and the food preferences update.
/// 4. On the next readings the engine sees the smaller energy deficit and
///    reacts (e.g. NUTRITION_DEFICIT goes down).
///
/// The meal history is not a separate database: it is the meal entries of
/// the Mission Log. One source of truth, so "Wipe local data" clears the log,
/// the history and the learned preferences together.
class NutritionController extends ChangeNotifier {
  NutritionController({
    required EngineController engine,
    required MissionLogController log,
    required this._energy,
    Future<List<Food>> Function()? loadFoods,
    this._recommender = const FoodRecommender(),
  }) : _engine = engine,
       _log = log {
    engine.addListener(_rebuildPlan);
    log.addListener(_onLogChanged);
    _onLogChanged();
    _ready = _load(loadFoods ?? loadFoodsFromAssets);
  }

  final EngineController _engine;
  final MissionLogController _log;
  final EnergyBalanceService _energy;
  final FoodRecommender _recommender;
  late final Future<void> _ready;
  bool _disposed = false;

  List<Food> _foods = const [];
  bool _loaded = false;
  String? _loadError;
  Map<String, FoodPreference> _preferences = const {};
  int _mealCount = -1;
  NutritionPlan _plan = NutritionPlan.empty;

  List<Food> get foods => _foods;
  bool get isLoaded => _loaded;
  String? get loadError => _loadError;
  NutritionPlan get plan => _plan;
  Map<String, FoodPreference> get preferences => _preferences;

  /// Completes when the food database is loaded (tests await it).
  Future<void> get ready => _ready;

  FoodPreference? preferenceOf(String foodId) => _preferences[foodId];

  Food? foodById(String id) {
    for (final f in _foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Foods whose name, category or tags contain [query] (case-insensitive).
  List<Food> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _foods;
    return _foods
        .where(
          (f) =>
              f.name.toLowerCase().contains(q) ||
              f.category.toLowerCase().contains(q) ||
              f.tags.any((t) => t.replaceAll('_', ' ').contains(q)),
        )
        .toList();
  }

  /// kcal actually eaten for a consumption level.
  static double kcalFor(Food food, int consumptionPct) =>
      food.kcal * consumptionPct / 100;

  /// Logs a meal. [answeredRisk] = the risk card it was picked from; if
  /// null, the current top risk (if any) is used.
  MealLogResult logMeal(
    Food food,
    int consumptionPct, {
    RiskType? answeredRisk,
  }) {
    final kcal = kcalFor(food, consumptionPct);
    return _record(
      foodId: food.id,
      name: food.name,
      pct: consumptionPct,
      kcal: kcal,
      risk: answeredRisk ?? _engine.latest?.topPrediction?.type,
    );
  }

  /// Demo Control "+600 kcal" button: goes through the same path as a real
  /// meal (energy + log), but has no food id, so it does not change the
  /// learned food preferences.
  MealLogResult logTestMeal() => _record(
    foodId: null,
    name: NutritionConstants.testMealName,
    pct: 100,
    kcal: NutritionConstants.testMealKcal,
    risk: _engine.latest?.topPrediction?.type,
  );

  MealLogResult _record({
    required String? foodId,
    required String name,
    required int pct,
    required double kcal,
    required RiskType? risk,
  }) {
    // 1) Energy balance: the engine sees the new deficit on the next reading.
    _energy.addIntake(kcal);
    // 2) Mission Log (stored encrypted). Its listener (_onLogChanged)
    //    then updates the preferences and the ranking.
    final entry = _log.recordMeal(
      foodId: foodId,
      foodName: name,
      consumptionPct: pct,
      kcalEaten: kcal,
      answeredRisk: risk,
    );
    return MealLogResult(
      foodName: name,
      consumptionPct: pct,
      kcalEaten: kcal,
      entry: entry,
    );
  }

  // --- Internals -------------------------------------------------------------------

  Future<void> _load(Future<List<Food>> Function() loader) async {
    try {
      _foods = await loader();
    } catch (e) {
      _loadError = 'Food database unavailable: $e';
    }
    if (_disposed) return;
    _loaded = true;
    _rebuildPlan();
  }

  /// Meal history → preferences (only when the number of meals changed).
  void _onLogChanged() {
    final meals = _log.mealEntries;
    if (meals.length == _mealCount) return;
    _mealCount = meals.length;
    _preferences = FoodRecommender.buildPreferences(_mealRecords(meals));
    _rebuildPlan();
  }

  static Iterable<MealRecord> _mealRecords(List<LogEntry> meals) sync* {
    for (final e in meals) {
      final id = e.data?['food_id'];
      final pct = e.data?['consumption_pct'];
      // Test meals have no food id: they do not teach preferences.
      if (id is String && pct is num) {
        yield (foodId: id, consumptionPct: pct.round());
      }
    }
  }

  void _rebuildPlan() {
    if (_disposed) return;
    _plan = _recommender.plan(
      _engine.latest?.predictions ?? const [],
      _foods,
      _preferences,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _engine.removeListener(_rebuildPlan);
    _log.removeListener(_onLogChanged);
    super.dispose();
  }
}
