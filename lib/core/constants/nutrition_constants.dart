import '../models/engine_result.dart';

/// Settings of the Predictive Nutrition Loop (Layer 3) and the Mission Log.
class NutritionConstants {
  NutritionConstants._();

  /// Bundled space food database.
  static const String foodsAsset = 'assets/data/foods.json';

  // --- Risk → preferred food tags (CLAUDE.md section 4, Layer 3) -------------
  // Each tag has a weight. A food's tag-match score = sum of the weights of
  // the tags it has / sum of all weights for that risk (0 … 1). Equal weights
  // mean every preferred tag counts the same; change a weight to favor one.
  static const Map<RiskType, Map<String, double>> riskTagWeights = {
    RiskType.fatigue: {'high_protein': 1.0, 'quick_energy': 1.0},
    RiskType.thermalStress: {
      'hydrating': 1.0,
      'electrolytes': 1.0,
      'low_sodium': 1.0,
    },
    RiskType.nutritionDeficit: {'high_calorie': 1.0, 'high_carb': 1.0},
    // Hypoxia: iron supports oxygen transport; the main advice is REST
    // (the non-food action from ActionAdvisor).
    RiskType.hypoxia: {'iron_rich': 1.0},
    RiskType.physiologicalStress: {'low_sodium': 1.0, 'hydrating': 1.0},
  };

  // --- Feedback learning ------------------------------------------------------
  // preference factor = base + (1 − base) × average fraction eaten.
  // Never eaten → 1.0 (no penalty). Always eaten at 25% → 0.5 + 0.5 × 0.25
  // = 0.625, so the food drops below a similar food the astronaut finishes.
  // The base keeps disliked foods visible (never multiplied down to zero).
  static const double preferenceBase = 0.5;

  /// "Ranked lower" reason is shown only if the factor is below this.
  static const double preferenceNoticeBelow = 0.95;

  /// How many predictions get their own recommendation card (worst first).
  static const int maxRecommendations = 2;

  /// Foods shown per recommendation.
  static const int foodsPerRecommendation = 3;

  /// Consumption levels the astronaut can log.
  static const List<int> consumptionLevels = [100, 75, 50, 25];
  static const int defaultConsumption = 100;

  /// Name of the Demo Control test meal in the log.
  static const String testMealName = 'Test meal';
  static const double testMealKcal = 600;

  /// Energy bar: the scale always shows at least this many kcal, so the
  /// 500 / 900 marks are visible even when the deficit is small.
  static const double energyBarMinScale = 1200;
}

/// Settings of the Mission Log.
class LogConstants {
  LogConstants._();

  /// Oldest entries are dropped beyond this (keeps storage small).
  static const int maxEntries = 500;

  /// A new alert level must be seen on this many readings in a row before it
  /// is logged. Stops the log from filling up when the score hovers right on
  /// a band edge (e.g. 39 ↔ 41).
  static const int statusConfirmReadings = 2;

  /// A risk must be absent this many readings in a row before it counts as
  /// gone. If it comes back later, it is logged again as a new prediction.
  static const int predictionClearReadings = 3;
}
