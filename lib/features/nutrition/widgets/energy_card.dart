import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/console_card.dart';
import '../../../app/widgets/risk_style.dart';
import '../../../app/widgets/status_chip.dart';
import '../../../core/constants/nutrition_constants.dart';
import '../../../core/constants/thresholds.dart';
import '../../../core/models/engine_result.dart';
import '../../../layers/nutrition/energy_balance_service.dart';

/// Energy balance: burned vs eaten, current deficit and a bar with the
/// 500 (warning) and 900 (critical) kcal marks.
class EnergyCard extends StatelessWidget {
  const EnergyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final energy = context.watch<EnergyBalanceService>();
    final status = energy.deficitStatus;
    final color = RiskStyle.statusColor(status);
    final label = switch (status) {
      RiskStatus.normal => 'Covered',
      RiskStatus.warning => 'Deficit',
      RiskStatus.critical => 'High deficit',
    };

    return ConsoleCard(
      label: 'Energy balance · kcal',
      trailing: StatusChip(
        icon: RiskStyle.statusIcon(status),
        label: label,
        color: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Figure(
                label: 'BURNED',
                value: energy.totalExpenditureKcal.round(),
              ),
              _Figure(label: 'EATEN', value: energy.totalEatenKcal.round()),
              _Figure(
                label: 'DEFICIT',
                value: energy.deficitKcal.round(),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DeficitBar(deficit: energy.deficitKcal, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Eaten = planned mission menu '
            '(${energy.totalPlannedKcal.round()}) + logged meals '
            '(${energy.totalIntakeKcal.round()}). Demo time runs ×60.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: AppTypography.vitalValue.copyWith(
                fontSize: 22,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar of the deficit with tick marks at 500 and 900 kcal.
class _DeficitBar extends StatelessWidget {
  const _DeficitBar({required this.deficit, required this.color});
  final double deficit;
  final Color color;

  static const double _barHeight = 10;

  @override
  Widget build(BuildContext context) {
    // The scale grows with the deficit, but always shows both marks.
    final scale = max(NutritionConstants.energyBarMinScale, deficit * 1.15);
    final marks = [
      Thresholds.energyDeficitWarning,
      Thresholds.energyDeficitCritical,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: _barHeight + AppSpacing.md + AppSpacing.xs,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: _barHeight,
                width: (deficit / scale).clamp(0.0, 1.0) * w,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
              ),
              for (final m in marks) ...[
                Positioned(
                  left: m / scale * w - 0.5,
                  top: -2,
                  child: Container(
                    width: 1,
                    height: _barHeight + 4,
                    color: AppColors.textSecondary,
                  ),
                ),
                Positioned(
                  left: m / scale * w - 12,
                  top: _barHeight + AppSpacing.xs,
                  child: SizedBox(
                    width: 24,
                    child: Text(
                      '$m',
                      textAlign: TextAlign.center,
                      style: AppTypography.monoSmall.copyWith(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
