import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/state/shell_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/widgets/console_card.dart';
import '../../../app/widgets/risk_style.dart';
import '../../../core/models/engine_result.dart';
import '../../../layers/nutrition/action_advisor.dart';

/// Recommended non-food action for the top risk, plus a button to the
/// Nutrition tab (ranked meals arrive there in Phase 4).
class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.top});

  /// Most serious prediction, or null when everything is nominal.
  final RiskPrediction? top;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = ActionAdvisor.forPrediction(top);

    return ConsoleCard(
      label: 'Recommended action',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.primary),
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Icon(
                  RiskStyle.actionIcon(action.kind),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.title, style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(action.detail, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  context.read<ShellNavigation>().open(AppTab.nutrition),
              icon: const Icon(Icons.restaurant, size: 18),
              label: const Text('See nutrition plan'),
            ),
          ),
        ],
      ),
    );
  }
}
