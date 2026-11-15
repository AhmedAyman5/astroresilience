import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/console_card.dart';
import '../../../app/widgets/hazard_tag.dart';
import '../../../app/widgets/risk_style.dart';
import '../../../app/widgets/status_chip.dart';
import '../../../core/models/alert_level.dart';
import '../../../layers/nutrition/action_advisor.dart';
import '../../../layers/nutrition/food_recommender.dart';
import 'meal_sheet.dart';

/// One active recommendation: the risk, its severity, the non-food action
/// and the top 3 foods with the reasons for their rank.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.recommendation});
  final RiskRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final p = recommendation.prediction;
    final level = AlertLevel.ofSeverity(p.severity);
    final text = Theme.of(context).textTheme;

    return ConsoleCard(
      label: 'Recommendation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.type.label,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                icon: RiskStyle.alertIcon(level),
                label: level.label,
                color: RiskStyle.alertColor(level),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: HazardChip(type: p.type),
          ),
          const SizedBox(height: AppSpacing.xs),
          HrpRiskLine(type: p.type),
          const SizedBox(height: AppSpacing.md),
          ActionRow(action: recommendation.action),
          const SizedBox(height: AppSpacing.md),
          const Text('TOP FOODS', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.sm),
          if (recommendation.foods.isEmpty)
            Text('No matching food in the database.', style: text.bodySmall)
          else
            for (final (i, ranked) in recommendation.foods.indexed) ...[
              if (i > 0) const Divider(height: AppSpacing.md),
              _RankedFoodRow(
                rank: i + 1,
                ranked: ranked,
                onLog: () =>
                    showMealSheet(context, ranked.food, answeredRisk: p.type),
              ),
            ],
        ],
      ),
    );
  }
}

/// Shown when nothing is predicted.
class RoutineCard extends StatelessWidget {
  const RoutineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      label: 'Recommendation',
      trailing: const StatusChip(
        icon: Icons.check_circle_outline,
        label: 'Nominal',
        color: AppColors.normal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No active risk — follow the planned menu',
            style: text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const ActionRow(action: ActionAdvisor.routine),
        ],
      ),
    );
  }
}

/// Non-food action: icon + title + one-line reason.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.action});
  final RecoveryAction action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.tint(AppColors.primary),
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          ),
          child: Icon(
            RiskStyle.actionIcon(action.kind),
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.title, style: text.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(action.detail, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankedFoodRow extends StatelessWidget {
  const _RankedFoodRow({
    required this.rank,
    required this.ranked,
    required this.onLog,
  });

  final int rank;
  final RankedFood ranked;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final food = ranked.food;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$rank',
            style: AppTypography.monoSmall.copyWith(color: AppColors.primary),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(food.name, style: text.titleSmall),
              Text(
                '${food.kcal} kcal · ${food.category}',
                style: AppTypography.monoSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              for (final reason in ranked.reasons)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        reason.startsWith('Ranked lower')
                            ? Icons.south
                            : Icons.check,
                        size: 12,
                        color: reason.startsWith('Ranked lower')
                            ? AppColors.warning
                            : AppColors.info,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(reason, style: text.bodySmall)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          key: Key('logRanked_${food.id}'),
          onPressed: onLog,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Text('Log'),
        ),
      ],
    );
  }
}
