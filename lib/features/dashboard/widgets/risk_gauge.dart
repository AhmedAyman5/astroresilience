import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/engine_constants.dart';
import '../../../core/constants/ui_constants.dart';

/// Risk gauge 0–100 drawn with a CustomPainter.
///
/// - A 240° arc. The faint background track shows the 3 status bands
///   (NORMAL 0–39, WARNING 40–69, CRITICAL 70–100), so the judges can see
///   where the needle sits relative to the bands.
/// - The solid arc = current score, in the alert color.
/// - Changes are animated: the arc glides to the new score in ~0.9 s
///   instead of jumping (TweenAnimationBuilder starts from the old value).
class RiskGauge extends StatelessWidget {
  const RiskGauge({super.key, required this.score, required this.color});

  /// Score 0–100.
  final int score;

  /// Color of the value arc (matches the status label under the gauge).
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = UiConstants.gaugeSize;
    return Semantics(
      label: 'Risk score $score out of 100',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: score.toDouble()),
        duration: UiConstants.gaugeAnimation,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return SizedBox(
            width: size,
            // A 240° arc only uses the top ~80% of its circle.
            height: size * 0.82,
            child: CustomPaint(
              painter: _GaugePainter(value: value, color: color),
              child: Align(
                alignment: const Alignment(0, 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.round().toString(),
                      style: AppTypography.vitalValue.copyWith(
                        fontSize: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text('RISK / 100', style: AppTypography.consoleLabel),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.color});

  final double value;
  final Color color;

  /// The arc starts bottom-left (150°) and sweeps 240° clockwise.
  static const double _start = 150 * pi / 180;
  static const double _sweep = 240 * pi / 180;

  /// Small gap between the 3 band segments of the track.
  static const double _bandGap = 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = UiConstants.gaugeStroke;
    final radius = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.width / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const max = EngineConstants.scoreMax;

    double angleOf(num score) => _sweep * (score / max);

    // 1) Background track split into the 3 status bands (dim colors).
    final bands = [
      (0, EngineConstants.scoreWarning, AppColors.normal),
      (
        EngineConstants.scoreWarning,
        EngineConstants.scoreCritical,
        AppColors.warning,
      ),
      (EngineConstants.scoreCritical, max, AppColors.critical),
    ];
    for (final (from, to, bandColor) in bands) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = bandColor.withValues(alpha: 0.18);
      final a = _start + angleOf(from) + (from == 0 ? 0 : _bandGap / 2);
      final b = _start + angleOf(to) - (to == max ? 0 : _bandGap / 2);
      canvas.drawArc(rect, a, b - a, false, paint);
    }

    // 2) Value arc.
    final v = value.clamp(0, max).toDouble();
    if (v > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, _start, angleOf(v), false, paint);
    }

    // 3) Small tick marks at the band boundaries (40 and 70).
    final tick = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.5;
    for (final s in [EngineConstants.scoreWarning, EngineConstants.scoreCritical]) {
      final angle = _start + angleOf(s);
      final dir = Offset(cos(angle), sin(angle));
      final inner = radius - stroke / 2 - 6;
      final outer = radius - stroke / 2 - 1;
      canvas.drawLine(center + dir * inner, center + dir * outer, tick);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color;
}
