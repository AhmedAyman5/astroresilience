import 'package:flutter/material.dart';

import '../../core/models/engine_result.dart';
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
    PredictionSeverity.watch => Icons.visibility_outlined,
    PredictionSeverity.warning => Icons.warning_amber_rounded,
    PredictionSeverity.critical => Icons.error_outline,
  };

  static IconData trendIcon(RiskTrend t) => switch (t) {
    RiskTrend.rising => Icons.trending_up,
    RiskTrend.stable => Icons.trending_flat,
    RiskTrend.falling => Icons.trending_down,
  };
}
