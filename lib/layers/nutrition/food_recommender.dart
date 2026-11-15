import '../../core/constants/nutrition_constants.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/food.dart';
import 'action_advisor.dart';

/// One past meal, as the recommender needs it.
typedef MealRecord = ({String foodId, int consumptionPct});

/// What the astronaut usually eats of one food (learned from meal history).
class FoodPreference {
  const FoodPreference({required this.timesLogged, required this.averagePct});

  final int timesLogged;

  /// Average consumption, 0–100 %.
  final double averagePct;
}

/// A food with its score and the plain-English reasons for its rank.
class RankedFood {
  const RankedFood({
    required this.food,
    required this.score,
    required this.tagScore,
    required this.preferenceFactor,
    required this.matchedTags,
    required this.reasons,
  });

  final Food food;

  /// Final score = [tagScore] × [preferenceFactor].
  final double score;
  final double tagScore;
  final double preferenceFactor;
  final List<String> matchedTags;

  /// e.g. "Matches: high_protein, quick_energy",
  ///      "Ranked lower: you usually eat about 25%".
  final List<String> reasons;
}

/// Recommendation for one predicted risk: a non-food action + top foods.
class RiskRecommendation {
  const RiskRecommendation({
    required this.prediction,
    required this.action,
    required this.foods,
  });

  final RiskPrediction prediction;
  final RecoveryAction action;
  final List<RankedFood> foods;
}

/// The whole nutrition plan for the current engine result.
class NutritionPlan {
  const NutritionPlan({required this.recommendations});

  /// Worst risk first, at most [NutritionConstants.maxRecommendations].
  /// Empty = no active risk: follow the planned menu + routine action.
  final List<RiskRecommendation> recommendations;

  bool get hasActiveRisk => recommendations.isNotEmpty;

  /// Non-food action when nothing is predicted.
  RecoveryAction get routineAction => ActionAdvisor.routine;

  static const NutritionPlan empty = NutritionPlan(recommendations: []);
}

/// Layer 3: ranks space foods for the risks the engine predicts.
///
/// Pure Dart (no Flutter), so it is easy to unit-test and explain.
///
/// HOW A FOOD IS SCORED
/// 1. Tag match: each risk has preferred tags with weights
///    (NutritionConstants.riskTagWeights). Tag score = weights of the tags
///    the food has ÷ all weights for that risk (0 … 1). Foods with no
///    matching tag are not recommended for that risk.
/// 2. Feedback learning (the "learns" part of the pitch): the app remembers
///    how much of each food the astronaut really ate (100/75/50/25 %).
///    preference factor = 0.5 + 0.5 × average fraction eaten.
///    - never logged → 1.0 (no penalty, we know nothing yet)
///    - always finished (100 %) → 1.0
///    - usually 25 % → 0.625: the food drops below a similar food the
///      astronaut actually finishes. A recommendation that is not eaten
///      does not help, so the system adapts to the person.
/// 3. Score = tag score × preference factor. Ties are broken by food id,
///    so the order is always the same for the same input (stable demo).
class FoodRecommender {
  const FoodRecommender({
    this.tagWeights = NutritionConstants.riskTagWeights,
    this.preferenceBase = NutritionConstants.preferenceBase,
  });

  final Map<RiskType, Map<String, double>> tagWeights;
  final double preferenceBase;

  /// Average consumption per food, from the meal history.
  static Map<String, FoodPreference> buildPreferences(
    Iterable<MealRecord> meals,
  ) {
    final count = <String, int>{};
    final sum = <String, int>{};
    for (final m in meals) {
      count[m.foodId] = (count[m.foodId] ?? 0) + 1;
      sum[m.foodId] = (sum[m.foodId] ?? 0) + m.consumptionPct;
    }
    return {
      for (final id in count.keys)
        id: FoodPreference(
          timesLogged: count[id]!,
          averagePct: sum[id]! / count[id]!,
        ),
    };
  }

  /// 1.0 if never logged, else base + (1 − base) × average fraction.
  double preferenceFactor(FoodPreference? p) {
    if (p == null || p.timesLogged == 0) return 1.0;
    final fraction = (p.averagePct / 100).clamp(0.0, 1.0);
    return preferenceBase + (1 - preferenceBase) * fraction;
  }

  /// All foods that match [risk], best first.
  List<RankedFood> rank(
    RiskType risk,
    List<Food> foods,
    Map<String, FoodPreference> preferences,
  ) {
    final weights = tagWeights[risk] ?? const <String, double>{};
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const [];

    final ranked = <RankedFood>[];
    for (final food in foods) {
      final matched = [
        for (final tag in weights.keys)
          if (food.hasTag(tag)) tag,
      ];
      if (matched.isEmpty) continue;
      final tagScore =
          matched.fold<double>(0, (a, t) => a + weights[t]!) / total;
      final pref = preferences[food.id];
      final factor = preferenceFactor(pref);
      ranked.add(
        RankedFood(
          food: food,
          score: tagScore * factor,
          tagScore: tagScore,
          preferenceFactor: factor,
          matchedTags: matched,
          reasons: [
            'Matches: ${matched.join(', ')}',
            if (pref != null &&
                factor < NutritionConstants.preferenceNoticeBelow)
              'Ranked lower: you usually eat about '
                  '${pref.averagePct.round()}%',
          ],
        ),
      );
    }
    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.food.id.compareTo(b.food.id);
    });
    return ranked;
  }

  /// Plan for the engine's predictions (already sorted worst first).
  NutritionPlan plan(
    List<RiskPrediction> predictions,
    List<Food> foods,
    Map<String, FoodPreference> preferences,
  ) {
    final recs = <RiskRecommendation>[];
    for (final p in predictions.take(NutritionConstants.maxRecommendations)) {
      recs.add(
        RiskRecommendation(
          prediction: p,
          action: ActionAdvisor.forPrediction(p),
          foods: rank(
            p.type,
            foods,
            preferences,
          ).take(NutritionConstants.foodsPerRecommendation).toList(),
        ),
      );
    }
    return NutritionPlan(recommendations: recs);
  }
}
