import 'package:flutter/animation.dart';

/// Light, calm animations of the "Nile & Gold" design (no magic numbers in
/// widgets). Every animation here plays ONCE and stops, so the widget tests
/// (pumpAndSettle) never wait forever.
class AppMotion {
  AppMotion._();

  /// Cards fade in and slide up slightly the first time they are built.
  static const Duration cardEntrance = Duration(milliseconds: 250);
  static const Curve cardEntranceCurve = Curves.easeOut;

  /// How far (px) a card slides up while it fades in.
  static const double cardEntranceOffset = 8;

  /// One gold shimmer sweep across the logo on the splash screen.
  static const Duration splashShimmer = Duration(milliseconds: 1500);
  static const Curve splashShimmerCurve = Curves.easeInOut;

  /// Strength (alpha) of the gold highlight in the shimmer.
  static const double splashShimmerAlpha = 0.55;
}
