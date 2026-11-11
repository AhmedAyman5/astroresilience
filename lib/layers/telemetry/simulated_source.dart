import 'dart:math';

import '../../core/constants/telemetry_constants.dart';
import '../../core/models/scenario.dart';
import '../../core/models/vital_reading.dart';
import 'scenario_profiles.dart';
import 'telemetry_source.dart';

/// Generates realistic vital readings for the demo.
///
/// How it stays realistic (good to explain to the judges):
/// 1. Switching scenario starts a smooth S-shaped ramp (90 s) from the
///    current values to the new scenario's targets: slow start, faster middle,
///    gentle arrival — like a real body. Values never jump.
/// 2. On top of that we add a bounded random walk (AR(1) noise): each step
///    keeps part of the previous noise, so values wander smoothly instead of
///    jumping around.
/// 3. Heart rate follows activity (moderate +20 bpm, high +45 bpm, eased over
///    ~20 s), and HRV falls with fatigue and stress (part of each scenario).
class SimulatedSource extends TelemetrySource {
  SimulatedSource({Random? random, Scenario scenario = Scenario.nominal})
    : _random = random ?? Random() {
    reset();
    _scenario = scenario;
  }

  final Random _random;
  Scenario _scenario = Scenario.nominal;

  // Ramp start values (where the vitals were when the scenario changed).
  late double _fromHr, _fromHrv, _fromSpo2, _fromTemp;

  // Ramp progress 0 → 1 toward the current scenario.
  double _progress = 1;

  // Current smooth values (before noise). _restHr excludes activity.
  late double _restHr, _hrv, _spo2, _temp;

  // Extra heart rate from activity, eased toward the activity target.
  double _hrBoostNow = 0;

  // Current noise of each vital (the random walk part).
  double _nHr = 0, _nHrv = 0, _nSpo2 = 0, _nTemp = 0;

  ActivityLevel _activity = ActivityLevel.low;

  @override
  String get label => 'Simulated';

  Scenario get scenario => _scenario;

  /// Switch scenario live: the vitals start a gradual ramp from where they
  /// are now toward the new targets.
  set scenario(Scenario value) {
    if (value == _scenario) return;
    _scenario = value;
    _fromHr = _restHr;
    _fromHrv = _hrv;
    _fromSpo2 = _spo2;
    _fromTemp = _temp;
    _progress = 0;
  }

  @override
  void reset() {
    // Start every session in a calm nominal state.
    final p = ScenarioProfiles.of(Scenario.nominal);
    _scenario = Scenario.nominal;
    _activity = ActivityLevel.low;
    _restHr = _fromHr = p.restingHr;
    _hrv = _fromHrv = p.hrv;
    _spo2 = _fromSpo2 = p.spo2;
    _temp = _fromTemp = p.temperature;
    _progress = 1;
    _hrBoostNow = 0;
    _nHr = _nHrv = _nSpo2 = _nTemp = 0;
  }

  @override
  VitalReading next(DateTime now, Duration interval) {
    final seconds = interval.inMilliseconds / 1000;
    final p = ScenarioProfiles.of(_scenario);

    _activity = _nextActivity(p, seconds);

    // Advance the ramp by real time, so the drift speed is the same whatever
    // interval (2 / 5 / 10 s) is selected.
    _progress = min(
      1,
      _progress + seconds / TelemetryConstants.scenarioRampSeconds,
    );
    // Smoothstep S-curve: 3p² − 2p³.
    final s = _progress * _progress * (3 - 2 * _progress);
    _restHr = _fromHr + (p.restingHr - _fromHr) * s;
    _hrv = _fromHrv + (p.hrv - _fromHrv) * s;
    _spo2 = _fromSpo2 + (p.spo2 - _fromSpo2) * s;
    _temp = _fromTemp + (p.temperature - _fromTemp) * s;

    // Heart rate responds to activity changes within ~20 s (exponential ease).
    final k = 1 - exp(-seconds / TelemetryConstants.activityTauSeconds);
    _hrBoostNow += (_hrBoost(_activity) - _hrBoostNow) * k;
    final hr = _restHr + _hrBoostNow;

    _nHr = _walk(_nHr, TelemetryConstants.hrNoise);
    _nHrv = _walk(_nHrv, TelemetryConstants.hrvNoise);
    _nSpo2 = _walk(_nSpo2, TelemetryConstants.spo2Noise);
    _nTemp = _walk(_nTemp, TelemetryConstants.tempNoise);

    return VitalReading(
      timestamp: now,
      heartRate: (hr + _nHr).round().clamp(
        TelemetryConstants.hrMin,
        TelemetryConstants.hrMax,
      ),
      hrv: (_hrv + _nHrv).round().clamp(
        TelemetryConstants.hrvMin,
        TelemetryConstants.hrvMax,
      ),
      spo2: (_spo2 + _nSpo2).round().clamp(
        TelemetryConstants.spo2Min,
        TelemetryConstants.spo2Max,
      ),
      temperature: VitalReading.roundTemperature(
        (_temp + _nTemp).clamp(
          TelemetryConstants.tempMin,
          TelemetryConstants.tempMax,
        ),
      ),
      activity: _activity,
    );
  }

  /// NOMINAL has short moderate stints now and then; other scenarios keep
  /// their main activity level.
  ActivityLevel _nextActivity(ScenarioProfile p, double seconds) {
    if (!p.occasionalModerate) return p.activity;
    if (_activity == ActivityLevel.moderate) {
      final stop = TelemetryConstants.nominalStopModeratePerSecond * seconds;
      return _random.nextDouble() < stop ? p.activity : ActivityLevel.moderate;
    }
    final start = TelemetryConstants.nominalStartModeratePerSecond * seconds;
    return _random.nextDouble() < start ? ActivityLevel.moderate : p.activity;
  }

  double _hrBoost(ActivityLevel a) => switch (a) {
    ActivityLevel.low => 0,
    ActivityLevel.moderate => TelemetryConstants.hrBoostModerate,
    ActivityLevel.high => TelemetryConstants.hrBoostHigh,
  };

  /// One step of the bounded AR(1) random walk.
  double _walk(double previous, double kick) {
    const phi = TelemetryConstants.noisePersistence;
    final next = phi * previous + kick * _gaussian();
    // Long-run spread of this noise is kick / sqrt(1 - phi²); clamp at 3×.
    final limit =
        TelemetryConstants.noiseClampSd * kick / sqrt(1 - phi * phi);
    return next.clamp(-limit, limit);
  }

  /// Standard normal random number (Box–Muller transform).
  double _gaussian() {
    final u1 = 1 - _random.nextDouble(); // avoid log(0)
    final u2 = _random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
