import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/risk_style.dart';
import '../../../core/constants/engine_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/models/vital_kind.dart';
import '../../../core/models/vital_reading.dart';
import '../../../core/utils/vital_analysis.dart';
import '../../../layers/engine/engine_controller.dart';
import '../../../layers/nutrition/energy_balance_service.dart';
import '../../../layers/telemetry/telemetry_controller.dart';
import 'sparkline.dart';

/// One vital on the dashboard: label, value (mono), unit, trend arrow,
/// sparkline of the last 12 readings and a status dot + text.
///
/// It rebuilds only when a new reading arrives (select on `revision`).
class VitalCard extends StatelessWidget {
  const VitalCard({super.key, required this.kind});

  final VitalKind kind;

  @override
  Widget build(BuildContext context) {
    context.select<TelemetryController, int>((t) => t.revision);
    final history = context.read<TelemetryController>().historyView;
    final baselineHrv = context.select<EngineController, double>(
      (e) => e.latest?.baselineHrv ?? EngineConstants.baselineSeedHrv,
    );

    final window = VitalAnalysis.lastN(
      history,
      UiConstants.sparklineReadings,
    );
    final latest = window.isEmpty ? null : window.last;
    final status = VitalAnalysis.status(
      kind,
      history,
      baselineHrv: baselineHrv,
    );
    final direction = VitalAnalysis.direction(kind, window);
    final t0 = history.isEmpty ? null : history.first.timestamp;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          // A warning/critical vital gets a colored border (plus the
          // icon + text below — never color alone).
          color: status == VitalRangeStatus.inRange
              ? AppColors.border
              : RiskStyle.rangeColor(status),
          width: AppSpacing.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${kind.label} · ${kind.unit.toUpperCase()}',
                  style: AppTypography.consoleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: RiskStyle.directionLabel(direction),
                child: Icon(
                  RiskStyle.directionIcon(direction),
                  size: 16,
                  color: AppColors.textSecondary,
                  semanticLabel: RiskStyle.directionLabel(direction),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Value(kind: kind, reading: latest),
          const SizedBox(height: AppSpacing.sm),
          Sparkline(
            xs: [
              for (final r in window)
                r.timestamp.difference(t0!).inMilliseconds / 1000,
            ],
            values: window.map(kind.valueOf).toList(),
            color: kind == VitalKind.activity
                ? AppColors.info
                : AppColors.primary,
            minSpan: VitalAnalysis.minSpan(kind),
            step: kind == VitalKind.activity,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (kind == VitalKind.activity)
            _ActivityFooter(activity: latest?.activity)
          else
            _StatusLine(status: status),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.kind, required this.reading});
  final VitalKind kind;
  final VitalReading? reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final text = r == null ? '--' : kind.format(kind.valueOf(r));
    final isActivity = kind == VitalKind.activity;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text,
            style: AppTypography.vitalValue.copyWith(fontSize: 28),
          ),
          if (!isActivity) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(kind.unit, style: AppTypography.monoSmall),
          ],
        ],
      ),
    );
  }
}

/// Small status dot + text, e.g. "● WARNING".
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});
  final VitalRangeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = RiskStyle.rangeColor(status);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
        Expanded(
          child: Text(
            status.label,
            style: AppTypography.consoleLabel.copyWith(
              color: status == VitalRangeStatus.inRange
                  ? AppColors.textSecondary
                  : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Activity has no thresholds: instead show the estimated energy burn and
/// the current energy deficit (input of the nutrition loop).
class _ActivityFooter extends StatelessWidget {
  const _ActivityFooter({required this.activity});
  final ActivityLevel? activity;

  @override
  Widget build(BuildContext context) {
    final deficit = context.select<EnergyBalanceService, int>(
      (e) => e.deficitKcal.round(),
    );
    final burn = activity == null
        ? '--'
        : EnergyBalanceService.kcalPerMinute(activity!).toStringAsFixed(1);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xxs,
      children: [
        Text('BURN $burn KCAL/MIN', style: AppTypography.consoleLabel),
        Text('ENERGY DEFICIT $deficit KCAL', style: AppTypography.consoleLabel),
      ],
    );
  }
}
