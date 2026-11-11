import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography for the "Pressure Suit" design system.
///
/// - IBM Plex Sans: all normal UI text.
/// - IBM Plex Mono: vital numbers, timestamps and IDs. Mono digits all have
///   the same width ("tabular"), so live numbers do not jump around as they
///   change — exactly like a mission-control console.
///
/// Both fonts are bundled in assets/fonts (no runtime download).
class AppTypography {
  AppTypography._();

  static const String sans = 'IBMPlexSans';
  static const String mono = 'IBMPlexMono';

  /// Material text theme built on Plex Sans.
  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontFamily: sans,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      height: 1.2,
    ),
    headlineSmall: TextStyle(
      fontFamily: sans,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      height: 1.25,
    ),
    titleLarge: TextStyle(
      fontFamily: sans,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: sans,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: sans,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: sans,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: sans,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: 0.4,
    ),
    labelMedium: TextStyle(
      fontFamily: sans,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: sans,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );

  /// Small uppercase console label, e.g. "HEART RATE · BPM".
  /// Pass the text already in uppercase.
  static const TextStyle consoleLabel = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textSecondary,
  );

  /// Large vital reading, e.g. "78".
  static const TextStyle vitalValue = TextStyle(
    fontFamily: mono,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  /// Small mono text for timestamps, IDs and inline numbers.
  static const TextStyle monoSmall = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Text inside the top-bar chips (uppercase, spaced, compact).
  static const TextStyle chip = TextStyle(
    fontFamily: sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.textPrimary,
  );

  /// Mono variant for numbers inside chips (e.g. "12m 40s").
  static const TextStyle chipMono = TextStyle(
    fontFamily: mono,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
