import 'package:flutter/material.dart';

/// "Pressure Suit" color palette (dark theme only).
///
/// Story for the judges: the primary color is International Orange — the
/// color of NASA launch-and-entry pressure suits. The app protects the
/// astronaut the way the suit does.
///
/// Every color in the app must come from here (no magic hex values in widgets).
class AppColors {
  AppColors._();

  // Surfaces — layered from darkest (page) to lightest (raised card).
  static const Color background = Color(0xFF121314);
  static const Color surface = Color(0xFF1A1C1E);
  static const Color surfaceRaised = Color(0xFF222528);
  static const Color border = Color(0xFF2E3236);

  // Text.
  static const Color textPrimary = Color(0xFFECE8E1);
  static const Color textSecondary = Color(0xFF9B9A96);

  // Brand: International Orange (buttons, active nav, key accents).
  static const Color primary = Color(0xFFE8743B);

  // Info: nutrition and secondary chart lines.
  static const Color info = Color(0xFF8DB4D6);

  // Health status colors. NOTE: status is never shown by color alone —
  // always pair these with an icon and a text label.
  static const Color normal = Color(0xFF6FB38E);
  static const Color warning = Color(0xFFF2C14E);
  static const Color critical = Color(0xFFE5484D);

  /// Text/icon color to use on top of a [primary] filled button.
  static const Color onPrimary = Color(0xFF121314);

  /// Subtle tinted background for chips and badges of a given accent color.
  static Color tint(Color color) => color.withValues(alpha: 0.12);
}
