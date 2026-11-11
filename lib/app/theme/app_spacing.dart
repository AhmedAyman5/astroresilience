/// Layout constants on an 8-point grid, plus shared shape values.
///
/// Keeping these in one place makes every screen feel consistent and avoids
/// magic numbers in widgets.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal padding of every screen.
  static const double screenPadding = md;

  /// Corner radius used by cards, sheets and buttons.
  static const double radius = 12;

  /// Chips are pill-shaped but slightly squarer, like console indicators.
  static const double chipRadius = 8;

  /// Cards use a 1px border and no shadow.
  static const double borderWidth = 1;

  /// Size of the logo in the top bar.
  static const double topBarLogo = 28;

  /// Size of the logo on the splash screen.
  static const double splashLogo = 112;

  /// Max content width so the layout stays readable on wide (web) screens.
  static const double maxContentWidth = 720;
}
