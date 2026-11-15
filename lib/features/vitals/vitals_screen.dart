import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/constants/ui_constants.dart';
import '../../core/models/vital_kind.dart';
import 'widgets/vital_chart_card.dart';

/// The 3 range options of the Vitals tab.
enum ChartRange {
  twoMin('2 min', UiConstants.range2Min),
  tenMin('10 min', UiConstants.range10Min),
  session('Session', null);

  const ChartRange(this.label, this.duration);
  final String label;

  /// null = the whole session.
  final Duration? duration;
}

/// Tab 2 — Vitals: one chart per vital, with dashed threshold lines and a
/// range toggle (2 min / 10 min / session).
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  // Only UI state lives here (which range is selected).
  ChartRange _range = ChartRange.twoMin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('vitalsList'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        const Text('RANGE', style: AppTypography.consoleLabel),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ChartRange>(
            showSelectedIcon: false,
            segments: [
              for (final r in ChartRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            onSelectionChanged: (v) => setState(() => _range = v.first),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Dashed lines: amber = warning, red = critical threshold.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final kind in VitalKind.values) ...[
          const SizedBox(height: AppSpacing.md),
          VitalChartCard(kind: kind, range: _range.duration),
        ],
      ],
    );
  }
}
