import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/engine_result.dart';
import '../../core/models/vital_reading.dart';
import '../nutrition/energy_balance_service.dart';
import '../telemetry/telemetry_controller.dart';
import 'adaptive_baseline.dart';
import 'edge_engine.dart';

/// Connects Layer 1 → Layer 2: listens to every telemetry reading, updates
/// the energy balance, runs the [EdgeEngine] and exposes the latest result
/// to the UI.
class EngineController extends ChangeNotifier {
  EngineController({
    required TelemetryController telemetry,
    required this.energy,
    EdgeEngine? engine,
  }) : _telemetry = telemetry,
       _engine = engine ?? EdgeEngine() {
    _sessionId = telemetry.sessionId;
    _sub = telemetry.readings.listen(_onReading);
    telemetry.addListener(_onTelemetryChanged);
    // A reading may already have been emitted before we subscribed. Process
    // it in a microtask: we are inside the provider's build right now, and
    // notifying listeners during a build is not allowed.
    final latest = telemetry.latest;
    if (latest != null) {
      scheduleMicrotask(() {
        if (!_disposed) _onReading(latest);
      });
    }
  }

  final TelemetryController _telemetry;
  /// Energy balance (Layer 3 input). Public so Phase 4 can log intake.
  final EnergyBalanceService energy;
  final EdgeEngine _engine;
  late final StreamSubscription<VitalReading> _sub;
  late int _sessionId;
  bool _disposed = false;

  /// Keep recent results for later phases (charts / log).
  static const int maxResults = 200;
  final List<EngineResult> _results = [];

  EngineResult? get latest => _results.isEmpty ? null : _results.last;
  List<EngineResult> get results => List.unmodifiable(_results);
  AdaptiveBaseline get baseline => _engine.baseline;

  void _onReading(VitalReading reading) {
    // Energy first, so the engine sees the up-to-date deficit.
    energy.recordReading(
      reading,
      _telemetry.interval,
      scheduledMealsEaten: !_telemetry.scheduledMealsSkipped,
    );
    final result = _engine.process(
      reading,
      energyDeficitKcal: energy.deficitKcal,
    );
    _results.add(result);
    if (_results.length > maxResults) _results.removeAt(0);
    notifyListeners();
  }

  /// When the telemetry session is reset, the engine and energy reset too.
  void _onTelemetryChanged() {
    if (_telemetry.sessionId == _sessionId) return;
    _sessionId = _telemetry.sessionId;
    _engine.reset();
    energy.reset();
    _results.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    _telemetry.removeListener(_onTelemetryChanged);
    super.dispose();
  }
}
