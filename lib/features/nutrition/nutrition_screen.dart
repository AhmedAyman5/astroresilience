import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../layers/nutrition/nutrition_controller.dart';
import 'widgets/energy_card.dart';
import 'widgets/food_card.dart';
import 'widgets/recommendation_card.dart';

/// Tab 3 — Predictive Nutrition.
///
/// Top to bottom: energy balance, active recommendations (worst risk first,
/// max 2), then the searchable list of every space food.
///
/// The only state kept here is the search text (pure UI). Ranking, logging
/// and learning live in NutritionController / FoodRecommender.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionController>();
    final plan = nutrition.plan;
    final foods = nutrition.search(_query);
    final text = Theme.of(context).textTheme;

    return ListView(
      key: const Key('nutritionList'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text(
          'Meals recommended from predicted risks.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        const EnergyCard(),
        const SizedBox(height: AppSpacing.md),
        if (!plan.hasActiveRisk)
          const RoutineCard()
        else
          for (final rec in plan.recommendations) ...[
            RecommendationCard(
              // Keyed by risk type so each card keeps its place while the
              // ranking updates every reading.
              key: ValueKey('rec_${rec.prediction.type.code}'),
              recommendation: rec,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        const SizedBox(height: AppSpacing.md),
        const Text('ALL SPACE FOODS', style: AppTypography.consoleLabel),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('foodSearch'),
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: text.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search name, category or tag',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!nutrition.isLoaded)
          // Static text, not a spinner: the tab is kept alive offstage and
          // an endless animation there would keep repainting.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('Loading food database…', style: text.bodySmall),
          )
        else if (nutrition.loadError != null)
          Text(nutrition.loadError!, style: text.bodySmall)
        else if (foods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('No food matches "$_query".', style: text.bodySmall),
          )
        else
          for (final food in foods) ...[
            FoodCard(key: ValueKey(food.id), food: food),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Approximate values inspired by ISS menu items, not official NASA '
          'nutrition data.',
          key: const Key('foodDisclaimer'),
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
