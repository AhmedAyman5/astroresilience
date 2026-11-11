/// App-wide constants that are not thresholds or theme values.
class AppConstants {
  AppConstants._();

  static const String appName = 'AstroResilience';

  /// How long the splash screen stays visible.
  static const Duration splashDuration = Duration(milliseconds: 1500);

  // --- Simulated Earth ↔ Mars communication delay ---------------------------
  // One-way light time between Earth and Mars really varies from about
  // 4 minutes (closest approach) to about 24 minutes (farthest apart).
  // We simulate a slowly drifting delay inside that range to show the
  // astronaut cannot wait for Earth: decisions must be made on the edge.
  static const Duration earthDelayMin = Duration(minutes: 4);
  static const Duration earthDelayMax = Duration(minutes: 24);
  static const Duration earthDelayStart = Duration(minutes: 12, seconds: 40);

  /// How often the displayed delay is updated.
  static const Duration earthDelayTick = Duration(seconds: 3);

  /// Max change of the delay per tick (keeps the drift slow and believable).
  static const int earthDelayMaxStepSeconds = 4;
}
