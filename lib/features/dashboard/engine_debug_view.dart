import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../app/widgets/risk_style.dart';
import '../../app/widgets/status_chip.dart';
import '../../core/constants/telemetry_constants.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/scenario.dart';
import '../../core/models/vital_reading.dart';
import '../../core/utils/time_format.dart';
import '../../layers/engine/engine_controller.dart';
import '../../layers/nutrition/energy_balance_service.dart';
import '../../layers/telemetry/telemetry_controller.dart';

/// TEMPORARY (Phase 2) debug view shown on the Mission tab.
/// Lets Ahmed switch scenarios live and watch the engine react.
/// Replaced by the real dashboard (Phase 3) and Demo Control (Phase 5).
class EngineDebugView extends StatelessWidget {
  const EngineDebugView({super.key});

  /// Test meal size for the debug "log intake" button.
  static const double testMealKcal = 600;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text('Mission Dashboard', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Temporary engine debug view (Phase 2).',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            const _ControlsCard(),
            const SizedBox(height: AppSpacing.md),
            const _ReadingCard(),
            const SizedBox(height: AppSpacing.md),
            const _EngineCard(),
            const SizedBox(height: AppSpacing.md),
            const _PredictionsSection(),
          ],
        ),
      ),
    );
  }
}

// --- Controls ------------------------------------------------------------------

class _ControlsCard extends StatelessWidget {
  const _ControlsCard();

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryController>();
    final isReplay = telemetry.sourceType == DataSourceType.replay;

    return ConsoleCard(
      label: 'Debug controls',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCENARIO', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.xs),
          _Bordered(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Scenario>(
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            isReplay
                ? 'Scenarios apply to the simulated source only.'
                : telemetry.scenario.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('INTERVAL', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.xs),
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
          if (isReplay && telemetry.replay.isLoaded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${telemetry.replay.loadedAsset} · row '
              '${telemetry.replay.position + 1}/${telemetry.replay.length}'
              ' · ${telemetry.replay.skippedRows} bad rows skipped',
              style: AppTypography.monoSmall,
            ),
          ],
          if (telemetry.sourceError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              telemetry.sourceError!,
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.critical,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: telemetry.resetSession,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset session'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.read<EnergyBalanceService>().addIntake(
                  EngineDebugView.testMealKcal,
                ),
                icon: const Icon(Icons.restaurant, size: 18),
                label: Text('Log +${EngineDebugView.testMealKcal.round()} kcal'),
              ),
            ],
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

// --- Live reading ----------------------------------------------------------------

class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    final reading = context.select<TelemetryController, VitalReading?>(
      (t) => t.latest,
    );
    if (reading == null) {
      return const ConsoleCard(
        label: 'Live reading',
        child: Text('Waiting for telemetry…'),
      );
    }
    return ConsoleCard(
      label: 'Live reading',
      trailing: Text(
        TimeFormat.clock(reading.timestamp),
        style: AppTypography.monoSmall,
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          _Metric('HEART RATE · BPM', '${reading.heartRate}'),
          _Metric('HRV · MS', '${reading.hrv}'),
          _Metric('SPO2 · %', '${reading.spo2}'),
          _Metric('TEMP · °C', reading.temperature.toStringAsFixed(1)),
          _Metric('ACTIVITY', reading.activity.label.toUpperCase()),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.consoleLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.vitalValue.copyWith(fontSize: 22)),
      ],
    );
  }
}

// --- Engine summary --------------------------------------------------------------

class _EngineCard extends StatelessWidget {
  const _EngineCard();

  @override
  Widget build(BuildContext context) {
    final result = context.watch<EngineController>().latest;
    if (result == null) {
      return const ConsoleCard(
        label: 'Edge engine',
        child: Text('Waiting for the first reading…'),
      );
    }
    final color = RiskStyle.statusColor(result.status);
    return ConsoleCard(
      label: 'Edge engine',
      trailing: StatusChip(
        icon: RiskStyle.statusIcon(result.status),
        label: result.status.label,
        color: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.riskScore}',
                style: AppTypography.vitalValue.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('/ 100 RISK SCORE', style: AppTypography.consoleLabel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _KeyValue(
            'Baseline HR / HRV',
            '${result.baselineHeartRate.toStringAsFixed(1)} bpm / '
                '${result.baselineHrv.toStringAsFixed(1)} ms',
          ),
          _KeyValue(
            'Baseline learning',
            result.baselineUpdated ? 'UPDATED (calm reading)' : 'PAUSED',
          ),
          _KeyValue(
            'Energy deficit',
            '${result.energyDeficitKcal.round()} kcal',
          ),
          _KeyValue(
            'Window',
            '${result.windowSize} readings',
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
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

// --- Predictions -----------------------------------------------------------------

class _PredictionsSection extends StatelessWidget {
  const _PredictionsSection();

  @override
  Widget build(BuildContext context) {
    final result = context.watch<EngineController>().latest;
    final predictions = result?.predictions ?? const <RiskPrediction>[];
    return ConsoleCard(
      label: 'Predictions (${predictions.length})',
      child: predictions.isEmpty
          ? Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.normal,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No risks predicted',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (final p in predictions) ...[
                  _PredictionTile(p),
                  if (p != predictions.last)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _PredictionTile extends StatelessWidget {
  const _PredictionTile(this.p);
  final RiskPrediction p;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = RiskStyle.severityColor(p.severity);
    final minutes = p.minutesToThreshold;
    return ConsoleCard(
      raised: true,
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.type.label,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(
                icon: RiskStyle.severityIcon(p.severity),
                label: p.severity.label,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('CONF ${p.confidence}%', style: AppTypography.monoSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    RiskStyle.trendIcon(p.trend),
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    p.trend.label.toUpperCase(),
                    style: AppTypography.monoSmall,
                  ),
                ],
              ),
              if (minutes != null)
                Text('THRESHOLD ~$minutes MIN', style: AppTypography.monoSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('WHY?', style: AppTypography.consoleLabel),
          const SizedBox(height: AppSpacing.xs),
          for (final reason in p.why)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text('• $reason', style: text.bodySmall),
            ),
        ],
      ),
    );
  }
}
