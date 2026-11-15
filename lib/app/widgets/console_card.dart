import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard card of the design system: surface color, 1px border, radius 12,
/// no shadow, with an optional small uppercase console label on top.
///
/// "Nile & Gold" touches (visual only):
/// - a thin gold line along the top edge, like the gold band of a
///   pharaonic collar;
/// - the card fades in and slides up a few pixels the first time it is
///   built (plays once, ~250 ms, then stops).
class ConsoleCard extends StatelessWidget {
  const ConsoleCard({
    super.key,
    required this.child,
    this.label,
    this.trailing,
    this.raised = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  /// Small uppercase heading, e.g. "HEART RATE · BPM".
  final String? label;

  /// Optional widget shown on the right of the label (e.g. a status badge).
  final Widget? trailing;

  final Widget child;

  /// Use the lighter "raised" surface for nested / emphasized cards.
  final bool raised;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder plays only when the card is first built; later
    // rebuilds (new readings) keep the end value, so nothing re-animates.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.cardEntrance,
      curve: AppMotion.cardEntranceCurve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * AppMotion.cardEntranceOffset),
          child: child,
        ),
      ),
      child: CustomPaint(
        foregroundPainter: const _GoldTopLinePainter(),
        child: _card(),
      ),
    );
  }

  Widget _card() {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: raised ? AppColors.surfaceRaised : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: AppColors.border,
          width: AppSpacing.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || trailing != null) ...[
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!.toUpperCase(),
                      style: AppTypography.consoleLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// Draws the thin gold line on the top edge of a card, between the rounded
/// corners (so it never fights the 12 px radius). Paint only: no layout
/// change, so it cannot cause overflow.
class _GoldTopLinePainter extends CustomPainter {
  const _GoldTopLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AppSpacing.radius;
    if (size.width <= inset * 2) return;
    const y = AppSpacing.borderWidth / 2;
    final paint = Paint()
      ..color = AppColors.goldLine
      ..strokeWidth = AppSpacing.borderWidth;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), paint);
  }

  @override
  bool shouldRepaint(covariant _GoldTopLinePainter oldDelegate) => false;
}
