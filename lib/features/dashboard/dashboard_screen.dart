import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../app/widgets/risk_style.dart';
import '../../core/constants/engine_constants.dart';
import '../../core/models/alert_level.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/vital_kind.dart';
import '../../core/utils/time_format.dart';
import '../../layers/engine/engine_controller.dart';
import 'widgets/action_card.dart';
import 'widgets/prediction_card.dart';
import 'widgets/risk_gauge.dart';
import 'widgets/vital_card.dart';

/// Tab 1 — Mission Dashboard.
///
/// Top to bottom: risk gauge + status, 5 vital cards, top prediction (or
/// "All systems nominal"), recommended action, and a footer that shows the
/// engine is learning (baseline) and how full its window is.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('dashboardList'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: const [
        _RiskCard(),
        SizedBox(height: AppSpacing.lg),
        _SectionLabel(),
        SizedBox(height: AppSpacing.sm),
        _VitalsGrid(),
        SizedBox(height: AppSpacing.lg),
        _PredictionsArea(),
        SizedBox(height: AppSpacing.md),
        _ActionArea(),
        SizedBox(height: AppSpacing.md),
        _EngineFooter(),
      ],
    );
  }
}

// --- Risk gauge ---------------------------------------------------------------

class _RiskCard extends StatelessWidget {
  const _RiskCard();

  @override
  Widget build(BuildContext context) {
    final result = context.watch<EngineController>().latest;
    final level = AlertLevel.of(result);
    final color = RiskStyle.alertColor(level);
    final text = Theme.of(context).textTheme;

    return ConsoleCard(
      label: 'Mission risk',
      child: Column(
        children: [
          RiskGauge(score: result?.riskScore ?? 0, color: color),
          const SizedBox(height: AppSpacing.sm),
          // Big status label: icon + text + color (never color alone).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(RiskStyle.alertIcon(level), color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                level.label,
                key: const Key('alertLabel'),
                style: text.titleLarge?.copyWith(
                  color: color,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _summary(result, level),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// One plain-English line under the status label.
  static String _summary(EngineResult? result, AlertLevel level) {
    if (result == null) return 'Waiting for the first reading…';
    final top = result.topPrediction;
    switch (level) {
      case AlertLevel.nominal:
        return 'All vitals inside the personal baseline.';
      case AlertLevel.watch:
        final minutes = top?.minutesToThreshold;
        return minutes == null
            ? '${top!.type.label} trending toward its threshold.'
            : '${top!.type.label} may reach warning in ~$minutes min.';
      case AlertLevel.warning:
      case AlertLevel.critical:
        return 'Top risk: ${top?.type.label ?? '—'}. '
            'Score combines ${result.predictions.length} weighted '
            '${result.predictions.length == 1 ? 'risk' : 'risks'}.';
    }
  }
}

// --- Vitals ---------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    final time = context.select<EngineController, DateTime?>(
      (e) => e.latest?.reading.timestamp,
    );
    return Row(
      children: [
        const Expanded(
          child: Text('VITALS · LIVE', style: AppTypography.consoleLabel),
        ),
        if (time != null)
          Text('LAST ${TimeFormat.clock(time)}', style: AppTypography.monoSmall),
      ],
    );
  }
}

/// 2-column grid on phones; Activity spans the full width.
class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid();

  static const double _gap = AppSpacing.sm + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: VitalCard(kind: VitalKind.heartRate)),
            SizedBox(width: _gap),
            Expanded(child: VitalCard(kind: VitalKind.hrv)),
          ],
        ),
        SizedBox(height: _gap),
        Row(
          children: [
            Expanded(child: VitalCard(kind: VitalKind.spo2)),
            SizedBox(width: _gap),
            Expanded(child: VitalCard(kind: VitalKind.temperature)),
          ],
        ),
        SizedBox(height: _gap),
        VitalCard(kind: VitalKind.activity),
      ],
    );
  }
}

// --- Predictions ------------------------------------------------------------------

class _PredictionsArea extends StatelessWidget {
  const _PredictionsArea();

  @override
  Widget build(BuildContext context) {
    final predictions = context.select<EngineController, List<RiskPrediction>>(
      (e) => e.latest?.predictions ?? const [],
    );
    if (predictions.isEmpty) return const _NominalCard();
    // Fixed key: the card keeps its "Why?" / "+N more" toggles open while
    // new readings arrive.
    return PredictionCard(
      key: const ValueKey('predictionCard'),
      predictions: predictions,
    );
  }
}

/// Calm state: reassuring message instead of an empty predictions area.
class _NominalCard extends StatelessWidget {
  const _NominalCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      label: 'Predictions',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_outlined,
            color: AppColors.normal,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All systems nominal', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No risk predicted. The edge engine keeps watching every '
                  'reading and learning the astronaut\'s personal baseline.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea();

  @override
  Widget build(BuildContext context) {
    final top = context.select<EngineController, RiskPrediction?>(
      (e) => e.latest?.topPrediction,
    );
    return ActionCard(top: top);
  }
}

// --- Footer: the "learning" part, visible ----------------------------------------

class _EngineFooter extends StatelessWidget {
  const _EngineFooter();

  @override
  Widget build(BuildContext context) {
    final result = context.watch<EngineController>().latest;
    final updated = result?.baselineUpdated ?? false;
    final window = result?.windowSize ?? 0;
    final baseline = result == null
        ? '--'
        : 'HR ${result.baselineHeartRate.toStringAsFixed(1)} · '
              'HRV ${result.baselineHrv.toStringAsFixed(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  updated ? Icons.sync : Icons.pause_circle_outline,
                  size: 14,
                  color: updated ? AppColors.normal : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'BASELINE LEARNING: ${updated ? 'UPDATED' : 'PAUSED'}',
                  style: AppTypography.consoleLabel,
                ),
              ],
            ),
            Text(
              'WINDOW: $window/${EngineConstants.windowSize} READINGS',
              style: AppTypography.consoleLabel,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('BASELINE $baseline', style: AppTypography.monoSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'The baseline learns only from calm readings, so stress never '
          'becomes the new "normal".',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
