import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard card of the design system: surface color, 1px border, radius 12,
/// no shadow, with an optional small uppercase console label on top.
class ConsoleCard extends StatelessWidget {
  const ConsoleCard({
    super.key,
    required this.child,
    this.label,
    this.trailing,
    this.raised = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  /// Small uppercase heading, e.g. "HEART RATE · BPM".
  final String? label;

  /// Optional widget shown on the right of the label (e.g. a status badge).
  final Widget? trailing;

  final Widget child;

  /// Use the lighter "raised" surface for nested / emphasized cards.
  final bool raised;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: raised ? AppColors.surfaceRaised : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: AppColors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || trailing != null) ...[
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!.toUpperCase(),
                      style: AppTypography.consoleLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}
