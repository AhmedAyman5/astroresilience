import '../../core/constants/engine_constants.dart';
import '../../core/constants/thresholds.dart';
import '../../core/models/vital_reading.dart';

/// The astronaut's PERSONAL baseline for heart rate and HRV — the "learning"
/// part of the engine.
///
/// Why: "normal" differs per person. An HRV of 40 ms is fine for one
/// astronaut and a warning sign for another. So instead of only fixed numbers,
/// the engine compares HRV with what is normal for THIS astronaut.
///
/// How: an exponential moving average (EMA):
///   baseline = baseline + alpha × (newValue − baseline)
/// Each calm reading pulls the baseline a little (alpha = 5%) toward itself,
/// so the baseline follows slow, healthy changes (e.g. better fitness during
/// the mission). The first few calm readings use a bigger alpha (30%) to move
/// quickly away from the generic starting guess.
///
/// Key safety rule: the baseline ONLY learns from CALM readings (low activity,
/// no threshold crossed). Otherwise, during an illness the engine would
/// slowly "learn" the bad values as normal and stop warning.
class AdaptiveBaseline {
  AdaptiveBaseline({
    double heartRate = EngineConstants.baselineSeedHr,
    double hrv = EngineConstants.baselineSeedHrv,
  }) : _seedHr = heartRate,
       _seedHrv = hrv,
       _hr = heartRate,
       _hrv = hrv;

  final double _seedHr;
  final double _seedHrv;
  double _hr;
  double _hrv;
  int _calmCount = 0;

  double get heartRate => _hr;
  double get hrv => _hrv;

  /// Number of calm readings learned from so far.
  int get calmReadings => _calmCount;

  bool get isWarmingUp => _calmCount < EngineConstants.baselineWarmupReadings;

  /// How far [hrv] is below the baseline, as a fraction: 0.25 = 25% lower.
  /// Negative when HRV is above baseline (good).
  double hrvDrop(num hrv) => _hrv <= 0 ? 0 : 1 - hrv / _hrv;

  /// A reading is calm when nothing is wrong and the astronaut is resting.
  bool isCalm(VitalReading r) {
    final restingAndSafe =
        r.activity == ActivityLevel.low &&
        r.heartRate < Thresholds.hrRestWarning &&
        r.spo2 >= Thresholds.spo2Warning &&
        r.temperature < Thresholds.tempWarning;
    if (!restingAndSafe) return false;
    // During warm-up the seed may be far from this person's real HRV, so we
    // cannot judge the HRV drop yet (otherwise we could never start learning).
    if (isWarmingUp) return true;
    return hrvDrop(r.hrv) < Thresholds.hrvDropWarning;
  }

  /// Learns from [r] if it is calm. Returns true if the baseline changed.
  bool update(VitalReading r) {
    if (!isCalm(r)) return false;
    final alpha = isWarmingUp
        ? EngineConstants.baselineWarmupAlpha
        : EngineConstants.baselineAlpha;
    _hr += alpha * (r.heartRate - _hr);
    _hrv += alpha * (r.hrv - _hrv);
    _calmCount++;
    return true;
  }

  void reset() {
    _hr = _seedHr;
    _hrv = _seedHrv;
    _calmCount = 0;
  }
}
