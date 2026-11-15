import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/console_card.dart';
import '../../../core/models/food.dart';
import 'meal_sheet.dart';

/// Full food card of the searchable list: name, category, kcal, macros,
/// sodium, tags and a "Log meal" button.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.food});
  final Food food;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: text.titleSmall),
                    Text(
                      food.category.toUpperCase(),
                      style: AppTypography.consoleLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${food.kcal} kcal',
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MacroLine(food: food),
          const SizedBox(height: AppSpacing.sm),
          TagChips(tags: food.tags),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: Key('logFood_${food.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => showMealSheet(context, food),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log meal'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "P 14 g · C 3 g · F 17 g · Na 380 mg" in mono, wraps on narrow screens.
class MacroLine extends StatelessWidget {
  const MacroLine({super.key, required this.food});
  final Food food;

  static String _g(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final items = [
      ('PROTEIN', '${_g(food.proteinG)} g'),
      ('CARBS', '${_g(food.carbsG)} g'),
      ('FAT', '${_g(food.fatG)} g'),
      ('SODIUM', '${food.sodiumMg} mg'),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (label, value) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.consoleLabel.copyWith(fontSize: 10),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Small nutrition tag chips ("high protein", "hydrating"…).
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags, this.highlight = const {}});
  final List<String> tags;

  /// Tags drawn in the info color (the ones that matched a risk).
  final Set<String> highlight;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm - AppSpacing.xxs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: highlight.contains(tag)
                  ? AppColors.tint(AppColors.info)
                  : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              tag.replaceAll('_', ' ').toUpperCase(),
              style: AppTypography.chip.copyWith(
                fontSize: 9.5,
                color: highlight.contains(tag)
                    ? AppColors.info
                    : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
