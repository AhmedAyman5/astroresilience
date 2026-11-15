import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/console_card.dart';
import '../../../app/widgets/risk_style.dart';
import '../../../app/widgets/status_chip.dart';
import '../../../core/models/alert_level.dart';
import '../../../core/models/engine_result.dart';

/// Top prediction of the engine, with an expandable "Why?" list.
/// If there are more predictions, "+N more" expands the rest.
///
/// Stateful only for the UI toggles (Why? open, more open). The toggles are
/// kept between readings, so the list does not collapse every 5 seconds.
class PredictionCard extends StatefulWidget {
  const PredictionCard({super.key, required this.predictions});

  /// Sorted, most serious first. Must not be empty.
  final List<RiskPrediction> predictions;

  @override
  State<PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<PredictionCard> {
  bool _showWhy = false;
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final top = widget.predictions.first;
    final others = widget.predictions.skip(1).toList();

    return ConsoleCard(
      label: 'Top prediction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PredictionHeader(prediction: top, large: true),
          const SizedBox(height: AppSpacing.sm),
          _PredictionMetrics(prediction: top),
          const SizedBox(height: AppSpacing.xs),
          _ToggleButton(
            key: const Key('whyToggle'),
            label: 'Why?',
            open: _showWhy,
            onTap: () => setState(() => _showWhy = !_showWhy),
          ),
          if (_showWhy) _WhyList(reasons: top.why),
          if (others.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            _ToggleButton(
              key: const Key('moreToggle'),
              label: _showMore ? 'Hide other risks' : '+${others.length} more',
              open: _showMore,
              onTap: () => setState(() => _showMore = !_showMore),
            ),
            if (_showMore)
              for (final p in others) ...[
                const SizedBox(height: AppSpacing.sm),
                _OtherPrediction(prediction: p),
              ],
          ],
        ],
      ),
    );
  }
}

/// Risk name + severity chip (icon + text + color).
class _PredictionHeader extends StatelessWidget {
  const _PredictionHeader({required this.prediction, this.large = false});
  final RiskPrediction prediction;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = AlertLevel.ofSeverity(prediction.severity);
    return Row(
      children: [
        Expanded(
          child: Text(
            prediction.type.label,
            style: large ? text.titleLarge : text.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatusChip(
          icon: RiskStyle.alertIcon(level),
          label: level.label,
          color: RiskStyle.alertColor(level),
        ),
      ],
    );
  }
}

/// Confidence, trend and "est. N min" (only when rising).
class _PredictionMetrics extends StatelessWidget {
  const _PredictionMetrics({required this.prediction});
  final RiskPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final minutes = p.minutesToThreshold;
    final style = AppTypography.monoSmall.copyWith(
      color: AppColors.textPrimary,
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('CONF ${p.confidence}%', style: style),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              RiskStyle.trendIcon(p.trend),
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(p.trend.label.toUpperCase(), style: style),
          ],
        ),
        if (p.trend == RiskTrend.rising && minutes != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                p.severity == PredictionSeverity.watch
                    ? 'EST. $minutes MIN TO WARNING'
                    : 'EST. $minutes MIN',
                style: style,
              ),
            ],
          ),
      ],
    );
  }
}

class _WhyList extends StatelessWidget {
  const _WhyList({required this.reasons});
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(reason, style: text.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A secondary prediction (shown after "+N more"): compact, with its reasons.
class _OtherPrediction extends StatelessWidget {
  const _OtherPrediction({required this.prediction});
  final RiskPrediction prediction;

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      raised: true,
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PredictionHeader(prediction: prediction),
          const SizedBox(height: AppSpacing.sm),
          _PredictionMetrics(prediction: prediction),
          _WhyList(reasons: prediction.why),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      iconAlignment: IconAlignment.end,
      icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
      label: Text(label),
    );
  }
}
