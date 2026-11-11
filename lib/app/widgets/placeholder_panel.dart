import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'console_card.dart';
import 'status_chip.dart';

/// Styled placeholder used by screens that are built in later phases.
///
/// Shows the screen title, a "STANDBY" badge (icon + text, never color only),
/// a one-line description and the list of upcoming modules.
class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.phase,
    required this.modules,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Which build phase delivers this screen, e.g. "PHASE 3".
  final String phase;

  /// Short list of what the screen will contain.
  final List<String> modules;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: text.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ConsoleCard(
              label: 'Module status',
              trailing: StatusChip(
                icon: Icons.schedule,
                label: 'Standby',
                value: phase,
                color: AppColors.warning,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final module in modules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xxs),
                            child: Icon(
                              Icons.radio_button_unchecked,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(module, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'EDGE ENGINE · OFFLINE · NO NETWORK CALLS',
              style: AppTypography.consoleLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
