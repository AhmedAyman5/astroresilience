import 'package:flutter/material.dart';

/// "Nile & Gold" color palette (dark theme only).
///
/// Story for the judges: Nile blue, pharaonic gold, sun yellow and faience
/// turquoise on black. The team is from Egypt: the gold of the pharaohs'
/// masks guards the astronaut, the Nile blue carries the data, and the
/// turquoise of ancient faience amulets means "all is well".
///
/// Every color in the app must come from here (no magic hex values in widgets).
class AppColors {
  AppColors._();

  // Surfaces — layered from darkest (page) to lightest (raised card).
  // Deep black, then black with a hint of Nile blue.
  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF131A24);
  static const Color surfaceRaised = Color(0xFF1A2433);
  static const Color border = Color(0xFF26354A);

  // Text: warm papyrus white + muted sand.
  static const Color textPrimary = Color(0xFFF3EBD8);
  static const Color textSecondary = Color(0xFFA79F8C);

  // Brand: Egyptian gold (buttons, active nav, key accents).
  static const Color primary = Color(0xFFD4A73A);

  // Info: nutrition and secondary chart lines (also the WATCH level).
  // WHY the lighter Nile blue: the deep #1F5FA8 is too dark to read as text
  // on the dark surfaces, so text/lines use #3D7BC4.
  static const Color info = Color(0xFF3D7BC4);

  /// Deep Nile blue, for decoration only (never for text).
  static const Color nileDeep = Color(0xFF1F5FA8);

  /// Faience turquoise: calm accent (same hue as [normal]).
  static const Color accent = Color(0xFF30B5A6);

  // Health status colors. NOTE: status is never shown by color alone —
  // always pair these with an icon and a text label.
  static const Color normal = Color(0xFF30B5A6); // faience turquoise
  static const Color warning = Color(0xFFF2C230); // sun yellow
  static const Color critical = Color(0xFFE5484D); // red (unchanged)

  /// Text/icon color to use on top of a [primary] filled button.
  static const Color onPrimary = Color(0xFF0B0B0D);

  /// Subtle tinted background for chips and badges of a given accent color.
  static Color tint(Color color) => color.withValues(alpha: 0.12);

  /// Faint gold used by the decorative lines (card top line, top bar motif).
  static final Color goldLine = primary.withValues(alpha: 0.55);
}
