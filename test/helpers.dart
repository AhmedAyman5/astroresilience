import 'package:astroresilience/core/models/engine_result.dart';
import 'package:astroresilience/core/models/vital_reading.dart';
import 'package:astroresilience/layers/engine/adaptive_baseline.dart';
import 'package:astroresilience/layers/engine/edge_engine.dart';

/// Shared helpers for the engine tests.
final DateTime t0 = DateTime(2026, 11, 14, 10);

/// Reading number [i], 5 seconds apart. Defaults are calm baseline values.
VitalReading reading(
  int i, {
  int hr = 70,
  int hrv = 50,
  int spo2 = 98,
  double temp = 36.6,
  ActivityLevel activity = ActivityLevel.low,
}) {
  return VitalReading(
    timestamp: t0.add(Duration(seconds: 5 * i)),
    heartRate: hr,
    hrv: hrv,
    spo2: spo2,
    temperature: VitalReading.roundTemperature(temp),
    activity: activity,
  );
}

/// Engine with a known baseline (HR 70, HRV 50).
EdgeEngine engineWithBaseline() =>
    EdgeEngine(baseline: AdaptiveBaseline(heartRate: 70, hrv: 50));

/// Feeds [count] readings built by [build] and returns the last result.
EngineResult feed(
  EdgeEngine engine,
  int count,
  VitalReading Function(int i) build, {
  double deficit = 0,
}) {
  late EngineResult result;
  for (var i = 0; i < count; i++) {
    result = engine.process(build(i), energyDeficitKcal: deficit);
  }
  return result;
}

RiskPrediction? prediction(EngineResult result, RiskType type) {
  for (final p in result.predictions) {
    if (p.type == type) return p;
  }
  return null;
}
