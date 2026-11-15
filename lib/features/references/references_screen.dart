import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../core/constants/hazard_constants.dart';
import '../../core/models/engine_result.dart';

/// References: the NASA / CSA articles that shaped the app, and how each one
/// is used. Plain text only: nothing here opens the network.
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('References')),
      body: ListView(
        key: const Key('referencesList'),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text(
            'Knowledge sources (articles, not data). Read offline; the app '
            'never opens a link.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          const ConsoleCard(
            label: 'NASA Human Research Program',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Ref(
                  title: '5 Hazards of Human Spaceflight',
                  use:
                      'Each predicted risk carries a related hazard chip '
                      '(e.g. Hostile/Closed Environment). "Distance from '
                      'Earth" is why the whole app runs on the edge.',
                ),
                _Ref(
                  title: 'Risks of Human Spaceflight',
                  use:
                      'Each risk shows a related HRP risk title (sleep, '
                      'hypoxia, EVA, food and nutrition, behavioral health).',
                ),
                _Ref(
                  title: 'Ongoing HRP Research in Space',
                  use:
                      'Shaped the idea of continuous wearable monitoring and '
                      'a personal baseline that adapts to each astronaut.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const ConsoleCard(
            label: 'Canadian Space Agency',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Ref(
                  title: 'Monitoring Radiation for Astronaut Health',
                  use:
                      'Radiation is NOT monitored in this MVP. A dosimeter '
                      'input is a planned extension of the telemetry layer.',
                ),
                _Ref(
                  title: 'Why Do We Conduct Science Experiments in Space?',
                  use:
                      'Crew health data from a mission is also science: the '
                      'exportable Mission Log keeps it in an open format.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConsoleCard(
            label: 'Related hazards used in the app',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in RiskType.values)
                  _Ref(
                    title: t.label,
                    use:
                        '${HazardConstants.of(t).hazard} · HRP: '
                        '${HazardConstants.of(t).hrpRisk}',
                  ),
                const _Ref(
                  title: 'Whole app',
                  use:
                      '${HazardConstants.distanceHazard} · '
                      '${HazardConstants.distanceReason}',
                ),
                Text(
                  'These links are "related" context chosen by the team, '
                  'not an official NASA classification.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'THRESHOLDS ARE GENERAL PHYSIOLOGY VALUES, NOT NASA FLIGHT RULES.',
            key: Key('referencesFooter'),
            style: AppTypography.consoleLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Ref extends StatelessWidget {
  const _Ref({required this.title, required this.use});
  final String title;
  final String use;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.menu_book_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(use, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
