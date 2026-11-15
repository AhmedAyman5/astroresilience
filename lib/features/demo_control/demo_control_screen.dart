import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../core/constants/telemetry_constants.dart';
import '../../core/models/scenario.dart';
import '../../layers/nutrition/energy_balance_service.dart';
import '../../layers/telemetry/telemetry_controller.dart';

/// Demo Control — opened from the top-bar icon. Drives the live demo:
/// scenario, reading interval, data source, session reset and a test meal.
///
/// Phase 3: functional with basic styling. Phase 5 adds security status,
/// "About: 5-layer architecture" and final polish.
class DemoControlScreen extends StatelessWidget {
  const DemoControlScreen({super.key});

  /// Size of the test meal logged by the "+600 kcal" button. Lets us show the
  /// energy deficit going down before the real meal logging (Phase 4).
  static const double testMealKcal = 600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Control')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: const [
          _ScenarioCard(),
          SizedBox(height: AppSpacing.md),
          _TelemetryCard(),
          SizedBox(height: AppSpacing.md),
          _SessionCard(),
          SizedBox(height: AppSpacing.lg),
          Text(
            'CHANGES APPLY LIVE · ALL DATA STAYS ON THIS DEVICE',
            style: AppTypography.consoleLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- Scenario ------------------------------------------------------------------

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard();

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryController>();
    final isReplay = telemetry.sourceType == DataSourceType.replay;

    return ConsoleCard(
      label: 'Scenario',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bordered(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Scenario>(
                key: const Key('scenarioDropdown'),
                value: telemetry.scenario,
                isExpanded: true,
                dropdownColor: AppColors.surfaceRaised,
                onChanged: isReplay
                    ? null
                    : (s) {
                        if (s != null) telemetry.setScenario(s);
                      },
                items: [
                  for (final s in Scenario.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isReplay
                ? 'Scenarios apply to the simulated source only.'
                : '${telemetry.scenario.description} '
                      'Vitals drift there over about 90 seconds.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// --- Telemetry: interval + source ------------------------------------------------

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard();

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryController>();
    final isReplay = telemetry.sourceType == DataSourceType.replay;
    final replay = telemetry.replay;

    return ConsoleCard(
      label: 'Telemetry',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('READING INTERVAL', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final s in TelemetryConstants.intervalOptionsSeconds)
                  ButtonSegment(value: s, label: Text('$s s')),
              ],
              selected: {telemetry.interval.inSeconds},
              onSelectionChanged: (v) =>
                  telemetry.setInterval(Duration(seconds: v.first)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('DATA SOURCE', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DataSourceType>(
              showSelectedIcon: false,
              segments: [
                for (final t in DataSourceType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {telemetry.sourceType},
              onSelectionChanged: telemetry.isLoadingSource
                  ? null
                  : (v) => telemetry.setSource(v.first),
            ),
          ),
          if (telemetry.isLoadingSource) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (isReplay && replay.isLoaded) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoLine(label: 'FILE', value: '${replay.loadedAsset}'),
            _InfoLine(
              label: 'ROW',
              value: '${replay.position + 1} / ${replay.length}',
            ),
            _InfoLine(label: 'BAD ROWS SKIPPED', value: '${replay.skippedRows}'),
          ],
          if (telemetry.sourceError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.critical,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    telemetry.sourceError!,
                    style: AppTypography.monoSmall.copyWith(
                      color: AppColors.critical,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --- Session ---------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard();

  @override
  Widget build(BuildContext context) {
    final telemetry = context.read<TelemetryController>();
    final deficit = context.select<EnergyBalanceService, int>(
      (e) => e.deficitKcal.round(),
    );
    return ConsoleCard(
      label: 'Session',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: 'ENERGY DEFICIT', value: '$deficit kcal'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  telemetry.resetSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session reset: scenario back to Nominal.'),
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset session'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.read<EnergyBalanceService>().addIntake(
                  DemoControlScreen.testMealKcal,
                ),
                icon: const Icon(Icons.restaurant, size: 18),
                label: Text(
                  'Log +${DemoControlScreen.testMealKcal.round()} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reset clears history, the learned baseline and the energy '
            'balance. The test meal lowers the energy deficit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// --- Small helpers -----------------------------------------------------------------

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.consoleLabel),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bordered extends StatelessWidget {
  const _Bordered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
