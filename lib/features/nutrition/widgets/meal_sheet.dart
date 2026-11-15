import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/nutrition_constants.dart';
import '../../../core/models/engine_result.dart';
import '../../../core/models/food.dart';
import '../../../layers/nutrition/nutrition_controller.dart';

/// Opens the "how much did you eat?" bottom sheet, logs the meal through the
/// NutritionController and shows a confirmation snackbar.
Future<void> showMealSheet(
  BuildContext context,
  Food food, {
  RiskType? answeredRisk,
}) async {
  final controller = context.read<NutritionController>();
  final messenger = ScaffoldMessenger.of(context);
  final pct = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radius),
      ),
      side: BorderSide(color: AppColors.border),
    ),
    builder: (_) => _MealSheet(food: food),
  );
  if (pct == null) return; // closed without logging
  final result = controller.logMeal(food, pct, answeredRisk: answeredRisk);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${result.foodName} · ${result.consumptionPct}% · '
          '+${result.kcalEaten.round()} kcal',
        ),
      ),
    );
}

/// Sheet content. Stateful only for the selected consumption level.
class _MealSheet extends StatefulWidget {
  const _MealSheet({required this.food});
  final Food food;

  @override
  State<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<_MealSheet> {
  int _pct = NutritionConstants.defaultConsumption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kcal = NutritionController.kcalFor(widget.food, _pct).round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LOG MEAL', style: AppTypography.consoleLabel),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.food.name, style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'HOW MUCH WAS EATEN?',
              style: AppTypography.consoleLabel,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                key: const Key('consumptionSelector'),
                showSelectedIcon: false,
                segments: [
                  for (final p in NutritionConstants.consumptionLevels)
                    ButtonSegment(value: p, label: Text('$p%')),
                ],
                selected: {_pct},
                onSelectionChanged: (v) => setState(() => _pct = v.first),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '+$kcal kcal of ${widget.food.kcal} kcal',
                    key: const Key('kcalPreview'),
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Logging what was really eaten teaches the recommender: foods '
              'often left unfinished rank lower next time.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('confirmLogMeal'),
                onPressed: () => Navigator.of(context).pop(_pct),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Log meal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
