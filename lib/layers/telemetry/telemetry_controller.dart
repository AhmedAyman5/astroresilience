import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/telemetry_constants.dart';
import '../../core/models/scenario.dart';
import '../../core/models/vital_reading.dart';
import 'replay_source.dart';
import 'scenario_profiles.dart';
import 'simulated_source.dart';
import 'telemetry_source.dart';

/// Which telemetry source feeds the app.
enum DataSourceType {
  simulated,
  replay;

  String get label => switch (this) {
    DataSourceType.simulated => 'Simulated',
    DataSourceType.replay => 'NASA Replay',
  };
}

/// Layer 1 state holder: runs the active source on a timer, keeps the
/// reading history and lets the UI change scenario, source and interval.
///
/// Other layers listen to [readings] (a broadcast stream). The UI listens to
/// this ChangeNotifier.
class TelemetryController extends ChangeNotifier {
  TelemetryController({
    SimulatedSource? simulated,
    ReplaySource? replay,
    Duration? interval,
    bool autoStart = true,
    DateTime Function()? clock,
  }) : _simulated = simulated ?? SimulatedSource(),
       _replay = replay ?? ReplaySource(),
       _interval =
           interval ??
           const Duration(seconds: TelemetryConstants.defaultIntervalSeconds),
       _clock = clock ?? DateTime.now {
    if (autoStart) start();
  }

  final SimulatedSource _simulated;
  final ReplaySource _replay;
  final DateTime Function() _clock;
  final StreamController<VitalReading> _out =
      StreamController<VitalReading>.broadcast();

  StreamSubscription<VitalReading>? _sub;
  Duration _interval;
  DataSourceType _sourceType = DataSourceType.simulated;
  final List<VitalReading> _history = [];
  bool _running = false;
  bool _loadingSource = false;
  String? _sourceError;
  int _sessionId = 0;

  /// Every new reading, for the engine and other layers.
  Stream<VitalReading> get readings => _out.stream;

  /// Readings of this session, oldest first.
  List<VitalReading> get history => List.unmodifiable(_history);
  VitalReading? get latest => _history.isEmpty ? null : _history.last;

  Duration get interval => _interval;
  Scenario get scenario => _simulated.scenario;
  DataSourceType get sourceType => _sourceType;
  bool get isRunning => _running;
  bool get isLoadingSource => _loadingSource;

  /// Last error when switching source (e.g. replay file missing), else null.
  String? get sourceError => _sourceError;

  /// Changes every time the session is reset, so listeners can reset too.
  int get sessionId => _sessionId;

  ReplaySource get replay => _replay;

  /// True when the simulated astronaut is skipping scheduled meals
  /// (NUTRITION_DEFICIT scenario). Used by the energy balance.
  bool get scheduledMealsSkipped =>
      _sourceType == DataSourceType.simulated &&
      ScenarioProfiles.of(_simulated.scenario).mealsSkipped;

  TelemetrySource get _active =>
      _sourceType == DataSourceType.simulated ? _simulated : _replay;

  /// Starts emitting. The first reading comes immediately so the screen is
  /// never empty, then one every [interval].
  void start() {
    _running = true;
    _subscribe(emitNow: true);
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _running = false;
    notifyListeners();
  }

  /// Switch scenario live (simulated source only). Vitals drift gradually.
  void setScenario(Scenario scenario) {
    if (scenario == _simulated.scenario) return;
    _simulated.scenario = scenario;
    notifyListeners();
  }

  void setInterval(Duration interval) {
    if (interval == _interval) return;
    _interval = interval;
    if (_running) _subscribe(emitNow: false);
    notifyListeners();
  }

  /// Switch between Simulated and NASA Replay. If the replay file cannot be
  /// loaded we stay on the current source and expose [sourceError].
  Future<void> setSource(DataSourceType type) async {
    if (type == _sourceType || _loadingSource) return;
    _sourceError = null;
    if (type == DataSourceType.replay) {
      _loadingSource = true;
      notifyListeners();
      try {
        await _replay.prepare();
      } catch (e) {
        _sourceError = 'Replay unavailable: $e';
        _loadingSource = false;
        notifyListeners();
        return;
      }
      _loadingSource = false;
    }
    _sourceType = type;
    if (_running) _subscribe(emitNow: true);
    notifyListeners();
  }

  /// New session: clears history and restarts the sources from scratch.
  /// Listeners see [sessionId] change and reset their own state.
  void resetSession() {
    _history.clear();
    _simulated.reset();
    _replay.reset();
    _sessionId++;
    notifyListeners();
    if (_running) _subscribe(emitNow: true);
  }

  void _subscribe({required bool emitNow}) {
    _sub?.cancel();
    if (emitNow) {
      final first = _active.next(_clock(), _interval);
      if (first != null) _onReading(first);
    }
    _sub = _active.stream(_interval, clock: _clock).listen(_onReading);
  }

  void _onReading(VitalReading reading) {
    _history.add(reading);
    if (_history.length > TelemetryConstants.maxHistory) _history.removeAt(0);
    _out.add(reading);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _out.close();
    super.dispose();
  }
}
