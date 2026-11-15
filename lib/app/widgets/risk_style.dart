import 'package:flutter/material.dart';

import '../../core/models/alert_level.dart';
import '../../core/models/engine_result.dart';
import '../../core/utils/vital_analysis.dart';
import '../../layers/nutrition/action_advisor.dart';
import '../theme/app_colors.dart';

/// Colors and icons for statuses, severities and trends.
/// Design rule: status is never shown by color alone — always use the icon
/// and the text label together with the color.
class RiskStyle {
  RiskStyle._();

  static Color statusColor(RiskStatus s) => switch (s) {
    RiskStatus.normal => AppColors.normal,
    RiskStatus.warning => AppColors.warning,
    RiskStatus.critical => AppColors.critical,
  };

  static IconData statusIcon(RiskStatus s) => switch (s) {
    RiskStatus.normal => Icons.check_circle_outline,
    RiskStatus.warning => Icons.warning_amber_rounded,
    RiskStatus.critical => Icons.error_outline,
  };

  static Color severityColor(PredictionSeverity s) => switch (s) {
    PredictionSeverity.watch => AppColors.info,
    PredictionSeverity.warning => AppColors.warning,
    PredictionSeverity.critical => AppColors.critical,
  };

  static IconData severityIcon(PredictionSeverity s) => switch (s) {
    PredictionSeverity.watch => Icons.radar,
    PredictionSeverity.warning => Icons.warning_amber_rounded,
    PredictionSeverity.critical => Icons.error_outline,
  };

  static IconData trendIcon(RiskTrend t) => switch (t) {
    RiskTrend.rising => Icons.trending_up,
    RiskTrend.stable => Icons.trending_flat,
    RiskTrend.falling => Icons.trending_down,
  };

  // --- Alert level (adds the WATCH stage) -------------------------------------
  // WATCH uses info blue + a radar icon so "predicted, not yet reached" is
  // clearly different from WARNING (amber) and CRITICAL (red).

  static Color alertColor(AlertLevel a) => switch (a) {
    AlertLevel.nominal => AppColors.normal,
    AlertLevel.watch => AppColors.info,
    AlertLevel.warning => AppColors.warning,
    AlertLevel.critical => AppColors.critical,
  };

  static IconData alertIcon(AlertLevel a) => switch (a) {
    AlertLevel.nominal => Icons.check_circle_outline,
    AlertLevel.watch => Icons.radar,
    AlertLevel.warning => Icons.warning_amber_rounded,
    AlertLevel.critical => Icons.error_outline,
  };

  // --- One vital out of range ---------------------------------------------------

  static Color rangeColor(VitalRangeStatus s) => switch (s) {
    VitalRangeStatus.inRange => AppColors.normal,
    VitalRangeStatus.warning => AppColors.warning,
    VitalRangeStatus.critical => AppColors.critical,
  };

  static IconData directionIcon(ValueDirection d) => switch (d) {
    ValueDirection.up => Icons.arrow_upward,
    ValueDirection.flat => Icons.arrow_forward,
    ValueDirection.down => Icons.arrow_downward,
  };

  static String directionLabel(ValueDirection d) => switch (d) {
    ValueDirection.up => 'Rising',
    ValueDirection.flat => 'Steady',
    ValueDirection.down => 'Falling',
  };

  // --- Non-food actions -----------------------------------------------------------

  static IconData actionIcon(ActionKind k) => switch (k) {
    ActionKind.rest => Icons.hotel_outlined,
    ActionKind.hydrate => Icons.water_drop_outlined,
    ActionKind.reduceActivity => Icons.directions_walk,
    ActionKind.breathing => Icons.air,
    ActionKind.routine => Icons.task_alt,
  };
}
