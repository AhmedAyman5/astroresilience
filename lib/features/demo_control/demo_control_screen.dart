import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/constants/telemetry_constants.dart';
import '../../core/models/scenario.dart';
import '../../core/constants/nutrition_constants.dart';
import '../../layers/nutrition/energy_balance_service.dart';
import '../../layers/nutrition/nutrition_controller.dart';
import '../../layers/security/security_service.dart';
import '../../layers/telemetry/telemetry_controller.dart';

/// Demo Control — opened from the top-bar icon. Drives the live demo.
/// Cards: Scenario, Telemetry (interval + source), Session, Security, About
/// (5-layer architecture + References).
class DemoControlScreen extends StatelessWidget {
  const DemoControlScreen({super.key});

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
          SizedBox(height: AppSpacing.md),
          _SecurityCard(),
          SizedBox(height: AppSpacing.md),
          _AboutCard(),
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
            // Data honesty: there is no NASA dataset for this challenge.
            if (replay.isSimulatedSample) ...[
              const StatusChip(
                key: Key('simulatedSampleChip'),
                icon: Icons.science_outlined,
                label: 'Simulated sample',
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No NASA dataset exists for this challenge. This sample is '
                'simulated; a real NASA file placed in assets/data/nasa/ '
                'replaces it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _InfoLine(label: 'FILE', value: '${replay.loadedAsset}'),
            _InfoLine(
              label: 'ROW',
              value: '${replay.position + 1} / ${replay.length}',
            ),
            _InfoLine(
              label: 'BAD ROWS SKIPPED',
              value: '${replay.skippedRows}',
            ),
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
                // Same path as a real meal: energy balance + Mission Log
                // (logged as "Test meal", it does not teach preferences).
                onPressed: () {
                  final r = context.read<NutritionController>().logTestMeal();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Logged ${r.foodName} · +${r.kcalEaten.round()} kcal',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.restaurant, size: 18),
                label: Text(
                  'Log +${NutritionConstants.testMealKcal.round()} kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reset clears telemetry, the learned baseline and the energy '
            'balance. The Mission Log and meal history are kept. The test '
            'meal lowers the energy deficit and is logged as "Test meal".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// --- Security (Layer 5) -----------------------------------------------------------

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityService>();
    final text = Theme.of(context).textTheme;
    final encrypted = security.isEncrypted;

    return ConsoleCard(
      label: 'Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                encrypted ? Icons.lock_outline : Icons.warning_amber,
                size: 20,
                color: encrypted ? AppColors.normal : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  encrypted
                      ? 'Local data: ${SecurityService.algorithm} encrypted'
                      : 'Local data: memory only (not saved)',
                  key: const Key('securityStatus'),
                  style: text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(label: 'STORED ENTRIES', value: '${security.storedCount}'),
          _InfoLine(
            label: 'KEY',
            value: encrypted ? 'Secure storage (on device)' : '—',
          ),
          if (security.openError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'Secure storage unavailable on this device/browser, so the '
                'log lives in memory only.',
                style: text.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('wipeData'),
            onPressed: security.isWiping ? null : () => _confirmWipe(context),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Wipe local data'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Wipe deletes the Mission Log, meal history and learned food '
            'preferences from this device. Monitoring keeps running.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context) async {
    final security = context.read<SecurityService>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Wipe local data?'),
        content: const Text(
          'This permanently deletes the Mission Log, the meal history and '
          'the learned food preferences stored on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          // Red only on the destructive confirm action.
          FilledButton.icon(
            key: const Key('confirmWipe'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await security.wipeLocalData();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Local data wiped: log, meal history and preferences.'),
      ),
    );
  }
}

// --- About ----------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  static const List<String> _layers = [
    'Telemetry Simulator',
    'Edge AI Engine',
    'Predictive Nutrition Loop',
    'Offline Dashboard',
    'On-device Security',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      label: 'About · 5-layer architecture',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, name) in _layers.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.monoSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(child: Text(name, style: text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'NO NETWORK · NO BACKEND · NO LOGIN',
            style: AppTypography.consoleLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: AppColors.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const Key('referencesTile'),
              leading: const Icon(
                Icons.menu_book_outlined,
                color: AppColors.primary,
              ),
              title: const Text('References'),
              subtitle: Text(
                'NASA HRP and CSA articles behind the app',
                style: text.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.references),
            ),
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
