/// Settings of the Telemetry Simulator (Layer 1).
class TelemetryConstants {
  TelemetryConstants._();

  // --- Reading interval ------------------------------------------------------
  static const List<int> intervalOptionsSeconds = [2, 5, 10];
  static const int defaultIntervalSeconds = 5;

  /// Readings kept in memory for the "session" chart range.
  static const int maxHistory = 1000;

  // --- Gradual drift ---------------------------------------------------------
  /// A scenario change plays out over 90 s (S-shaped ramp), never instantly.
  static const double scenarioRampSeconds = 90;

  /// Heart rate follows activity changes with this time constant (~95% of
  /// the change after 3 × 20 s = 60 s).
  static const double activityTauSeconds = 20;

  // --- Noise (bounded random walk) -------------------------------------------
  /// Noise is "AR(1)": each step keeps 60% of the previous noise and adds a
  /// small random kick. This gives smooth wandering instead of jumpy noise.
  static const double noisePersistence = 0.6;

  /// Size of the random kick per reading (standard deviation).
  static const double hrNoise = 1.0;
  static const double hrvNoise = 0.8;
  static const double spo2Noise = 0.3;
  static const double tempNoise = 0.03;

  /// Noise is clamped at 3 standard deviations, so values stay bounded.
  static const double noiseClampSd = 3;

  // --- Heart rate vs activity ------------------------------------------------
  /// Extra bpm on top of the resting heart rate for each activity level.
  static const double hrBoostModerate = 20;
  static const double hrBoostHigh = 45;

  // --- NOMINAL scenario: occasional moderate activity ------------------------
  /// Chance per second to start / stop a short moderate-activity stint.
  static const double nominalStartModeratePerSecond = 0.01;
  static const double nominalStopModeratePerSecond = 0.04;

  // --- Physiological limits the simulator never goes beyond ------------------
  static const int hrMin = 35;
  static const int hrMax = 210;
  static const int hrvMin = 5;
  static const int hrvMax = 200;
  static const int spo2Min = 70;
  static const int spo2Max = 100;
  static const double tempMin = 34.0;
  static const double tempMax = 41.5;

  // --- NASA replay -------------------------------------------------------------
  /// Folder scanned for replay files (.json or .csv).
  static const String replayFolder = 'assets/data/nasa/';

  /// Bundled demo file, used when no real NASA file is present.
  static const String sampleReplayAsset = 'assets/data/nasa/sample_replay.json';

  /// Rows outside these limits are treated as bad data and skipped.
  static const int validHrMin = 25;
  static const int validHrMax = 250;
  static const int validHrvMin = 1;
  static const int validHrvMax = 300;
  static const int validSpo2Min = 50;
  static const int validSpo2Max = 100;
  static const double validTempMin = 30.0;
  static const double validTempMax = 43.0;

  /// A temperature above this is assumed to be in °F and converted to °C.
  static const double fahrenheitGuess = 50.0;
}
