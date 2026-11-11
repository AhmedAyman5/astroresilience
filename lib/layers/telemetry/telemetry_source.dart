import '../../core/models/vital_reading.dart';

/// Common interface for everything that produces vital readings.
///
/// Two implementations:
/// - SimulatedSource: generates realistic readings for the demo scenarios.
/// - ReplaySource: replays real (NASA) data from assets/data/nasa/.
///
/// The rest of the app does not care which one is active — that is the point
/// of the interface (real smart patches could be plugged in the same way).
abstract class TelemetrySource {
  /// Short name for the UI, e.g. "Simulated".
  String get label;

  /// Loads whatever the source needs (files etc.). Called before use.
  Future<void> prepare() async {}

  /// Produces the next reading, stamped with [now]. [interval] is the time
  /// since the previous reading. Returns null if no data is available.
  VitalReading? next(DateTime now, Duration interval);

  /// Back to the initial state (new session).
  void reset();

  /// A stream that emits one reading every [interval].
  Stream<VitalReading> stream(
    Duration interval, {
    DateTime Function() clock = DateTime.now,
  }) {
    return Stream<VitalReading?>.periodic(
      interval,
      (_) => next(clock(), interval),
    ).where((r) => r != null).cast<VitalReading>();
  }
}
