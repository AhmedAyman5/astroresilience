import 'package:flutter/material.dart';

import '../../core/constants/hazard_constants.dart';
import '../../core/models/engine_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Small chip "NASA HAZARD · SHORT NAME" for a risk type.
/// It shows RELATED NASA context (see HazardConstants), not an official
/// classification. Ellipsis instead of overflow on narrow phones.
class HazardChip extends StatelessWidget {
  const HazardChip({super.key, required this.type});
  final RiskType type;

  @override
  Widget build(BuildContext context) {
    final link = HazardConstants.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public, size: 12, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'NASA HAZARD · ${link.shortName}',
              key: const Key('hazardChip'),
              style: AppTypography.chip.copyWith(fontSize: 9.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small line "Related HRP risk: …" (wraps on narrow phones).
class HrpRiskLine extends StatelessWidget {
  const HrpRiskLine({super.key, required this.type});
  final RiskType type;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Related HRP risk: ${HazardConstants.of(type).hrpRisk}',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontStyle: FontStyle.italic),
    );
  }
}
