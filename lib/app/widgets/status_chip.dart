import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Compact console indicator chip: icon + uppercase text (+ optional mono value).
///
/// Used for the top-bar chips ("OFFLINE · EDGE MODE", "EARTH LINK DELAY")
/// and for status badges. Status is never shown by color alone, so the chip
/// always carries an icon AND a text label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;

  /// Uppercase label text.
  final String label;

  /// Optional value shown in mono font after the label (e.g. "12m 40s").
  final String? value;

  /// Accent color for the icon and border tint.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: AppColors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
          Text(label.toUpperCase(), style: AppTypography.chip),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(value!, style: AppTypography.chipMono.copyWith(color: color)),
          ],
        ],
      ),
    );
  }
}
