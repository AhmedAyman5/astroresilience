import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/nutrition_constants.dart';
import '../../core/models/alert_level.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/scenario.dart';
import '../engine/engine_controller.dart';
import '../security/log_store.dart';
import '../telemetry/telemetry_controller.dart';

/// Filter chips of the Log tab.
enum LogFilter {
  all,
  alerts,
  meals,
  system;

  String get label => switch (this) {
    LogFilter.all => 'All',
    LogFilter.alerts => 'Alerts',
    LogFilter.meals => 'Meals',
    LogFilter.system => 'System',
  };

  /// Alerts = status changes + predictions.
  bool accepts(LogEntryType t) => switch (this) {
    LogFilter.all => true,
    LogFilter.alerts =>
      t == LogEntryType.status || t == LogEntryType.prediction,
    LogFilter.meals => t == LogEntryType.meal,
    LogFilter.system => t == LogEntryType.system,
  };
}

/// The Mission Log: a timeline of what the system saw and what the astronaut
/// did. Feeds the Log tab and the meal history (Nutrition learning).
///
/// It does NOT write one entry per reading (that would be 720 entries an
/// hour). It only records CHANGES:
/// - status: the alert level changed (confirmed on 2 readings in a row);
/// - prediction: a new risk appeared, or an existing one got more serious;
/// - meal: every meal the astronaut logs;
/// - system: scenario / source change and session reset (simulator events).
///
/// Every entry is also written to the [LogStore] (encrypted on device), so
/// the log survives an app restart. Reset session keeps the log on purpose:
/// the meal history is what the recommender learns from. Only "Wipe local
/// data" clears it.
class MissionLogController extends ChangeNotifier {
  MissionLogController({
    required this._store,
    required EngineController engine,
    required TelemetryController telemetry,
    DateTime Function()? clock,
  }) : _engine = engine,
       _telemetry = telemetry,
       _clock = clock ?? DateTime.now {
    _scenario = telemetry.scenario;
    _source = telemetry.sourceType;
    _sessionId = telemetry.sessionId;
    engine.addListener(_onEngine);
    telemetry.addListener(_onTelemetry);
    _loading = load();
  }

  final LogStore _store;
  final EngineController _engine;
  final TelemetryController _telemetry;
  final DateTime Function() _clock;
  static const Uuid _uuid = Uuid();

  /// Oldest first (the UI reverses it).
  final List<LogEntry> _entries = [];
  bool _loaded = false;
  bool _disposed = false;
  late final Future<void> _loading;
  int _revision = 0;

  // --- What has been logged so far (to detect changes) -----------------------
  EngineResult? _lastResult;
  AlertLevel _loggedLevel = AlertLevel.nominal;
  AlertLevel? _pendingLevel;
  int _pendingCount = 0;

  /// Risks currently "open" in the log, with the worst severity logged.
  final Map<RiskType, PredictionSeverity> _openRisks = {};

  /// Readings in a row each open risk has been absent.
  final Map<RiskType, int> _absent = {};

  late Scenario _scenario;
  late DataSourceType _source;
  late int _sessionId;

  // --- Public API ----------------------------------------------------------------

  /// All entries, newest first.
  List<LogEntry> get entriesNewestFirst => List.unmodifiable(_entries.reversed);

  /// Entries for one filter chip, newest first.
  List<LogEntry> filtered(LogFilter filter) =>
      _entries.reversed.where((e) => filter.accepts(e.type)).toList();

  /// All entries, oldest first (export order).
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Meal entries only: this IS the meal history the recommender learns from.
  List<LogEntry> get mealEntries =>
      _entries.where((e) => e.type == LogEntryType.meal).toList();

  int get length => _entries.length;

  /// Goes up by one on every change; widgets can select on it.
  int get revision => _revision;

  /// True once the stored log has been read back.
  bool get isLoaded => _loaded;

  /// Completes when the stored log has been loaded (tests await it).
  Future<void> get ready => _loading;

  /// Reads the stored log back (called once at start). Entries recorded
  /// while loading are kept and merged by time.
  Future<void> load() async {
    List<Map<String, dynamic>> raw = const [];
    try {
      raw = await _store.loadAll();
    } catch (e) {
      debugPrint('Mission log: could not load stored entries: $e');
    }
    if (_disposed) return;
    final stored = <LogEntry>[];
    for (final map in raw) {
      try {
        stored.add(LogEntry.fromJson(map));
      } catch (_) {
        // A damaged entry is skipped, never a crash.
      }
    }
    final known = _entries.map((e) => e.id).toSet();
    _entries.insertAll(0, stored.where((e) => !known.contains(e.id)));
    // Stable sort: entries with the same time keep their order.
    mergeSort(_entries, compare: (a, b) => a.timestamp.compareTo(b.timestamp));
    _trim();
    _loaded = true;
    _changed();
  }

  /// Records a meal (called by the NutritionController).
  LogEntry recordMeal({
    required String? foodId,
    required String foodName,
    required int consumptionPct,
    required double kcalEaten,
    RiskType? answeredRisk,
  }) {
    final answered = answeredRisk == null
        ? 'Planned menu (no active risk).'
        : 'Answers: ${answeredRisk.label}.';
    return _add(
      LogEntryType.meal,
      title: '$foodName · $consumptionPct%',
      detail: '+${kcalEaten.round()} kcal eaten. $answered',
      data: {
        'food_id': foodId,
        'food_name': foodName,
        'consumption_pct': consumptionPct,
        'kcal_eaten': kcalEaten.round(),
        'risk': answeredRisk?.code,
      },
    );
  }

  /// Wipe: deletes every entry in memory AND in storage.
  Future<void> clearAll() async {
    _entries.clear();
    _changed();
    await _store.clearAll();
  }

  /// Pretty-printable export (oldest first).
  Map<String, dynamic> exportJson({required String storage}) => {
    'app': 'AstroResilience OS',
    'exported_at': _clock().toIso8601String(),
    'storage': storage,
    'entry_count': _entries.length,
    'entries': _entries.map((e) => e.toJson()).toList(),
  };

  // --- Engine: status + predictions ---------------------------------------------

  void _onEngine() {
    final result = _engine.latest;
    // The engine also notifies on reset (latest == null): nothing to log.
    if (result == null || identical(result, _lastResult)) return;
    _lastResult = result;
    _trackPredictions(result);
    _trackStatus(result);
  }

  void _trackStatus(EngineResult result) {
    final level = AlertLevel.of(result);
    if (level == _loggedLevel) {
      _pendingLevel = null;
      _pendingCount = 0;
      return;
    }
    // A new level must hold for a few readings before it is logged, so a
    // score hovering on a band edge does not spam the log.
    if (level == _pendingLevel) {
      _pendingCount++;
    } else {
      _pendingLevel = level;
      _pendingCount = 1;
    }
    if (_pendingCount < LogConstants.statusConfirmReadings) return;

    final from = _loggedLevel;
    _loggedLevel = level;
    _pendingLevel = null;
    _pendingCount = 0;
    final top = result.topPrediction;
    _add(
      LogEntryType.status,
      title: 'Status ${from.label} → ${level.label}',
      detail: top == null
          ? 'Risk score ${result.riskScore}. No risk predicted.'
          : 'Risk score ${result.riskScore}. Top risk: ${top.type.label}.',
      data: {
        'level': level.label,
        'previous_level': from.label,
        'risk_score': result.riskScore,
        'status': result.status.code,
        'top_risk': top?.type.code,
      },
    );
  }

  void _trackPredictions(EngineResult result) {
    final present = <RiskType>{};
    for (final p in result.predictions) {
      present.add(p.type);
      _absent[p.type] = 0;
      final logged = _openRisks[p.type];
      if (logged == null) {
        _openRisks[p.type] = p.severity;
        _logPrediction(p, escalated: false);
      } else if (p.severity.index > logged.index) {
        _openRisks[p.type] = p.severity;
        _logPrediction(p, escalated: true);
      }
    }
    // A risk that stays away for a few readings is closed; if it comes back
    // later it is logged again.
    for (final type in _openRisks.keys.toList()) {
      if (present.contains(type)) continue;
      final absent = (_absent[type] ?? 0) + 1;
      _absent[type] = absent;
      if (absent >= LogConstants.predictionClearReadings) {
        _openRisks.remove(type);
        _absent.remove(type);
      }
    }
  }

  void _logPrediction(RiskPrediction p, {required bool escalated}) {
    final level = AlertLevel.ofSeverity(p.severity);
    final minutes = p.minutesToThreshold;
    final eta = p.trend == RiskTrend.rising && minutes != null
        ? ' · est. $minutes min'
        : '';
    _add(
      LogEntryType.prediction,
      title: escalated
          ? '${p.type.label} escalated → ${level.label}'
          : '${p.type.label} predicted · ${level.label}',
      detail:
          'Confidence ${p.confidence}% · trend ${p.trend.label.toLowerCase()}'
          '$eta',
      data: {
        'risk': p.type.code,
        'severity': p.severity.code,
        'level': level.label,
        'confidence': p.confidence,
        'trend': p.trend.code,
        'minutes_to_threshold': minutes,
        'why': p.why,
      },
    );
  }

  // --- Telemetry: simulator events -------------------------------------------------

  void _onTelemetry() {
    final t = _telemetry;
    if (t.sessionId != _sessionId) {
      _sessionId = t.sessionId;
      _scenario = t.scenario; // reset also puts the scenario back to NOMINAL
      // A new session starts calm: forget open risks and the alert level.
      _openRisks.clear();
      _absent.clear();
      _loggedLevel = AlertLevel.nominal;
      _pendingLevel = null;
      _pendingCount = 0;
      _lastResult = null;
      _addSystem(
        'Session reset',
        'Telemetry, baseline and energy balance restarted. The log and '
            'meal history are kept.',
        {'event': 'session_reset'},
      );
    }
    if (t.scenario != _scenario) {
      _scenario = t.scenario;
      _addSystem('Scenario → ${t.scenario.label}', t.scenario.description, {
        'event': 'scenario_change',
        'scenario': t.scenario.code,
      });
    }
    if (t.sourceType != _source) {
      _source = t.sourceType;
      _addSystem(
        'Data source → ${t.sourceType.label}',
        t.sourceType == DataSourceType.replay
            ? 'Replaying the bundled file (a simulated sample).'
            : 'Built-in telemetry simulator.',
        {'event': 'source_change', 'source': t.sourceType.name},
      );
    }
  }

  void _addSystem(String title, String detail, Map<String, dynamic> data) {
    _add(
      LogEntryType.system,
      title: title,
      detail: 'Simulator event. $detail',
      data: {...data, 'simulated': true},
    );
  }

  // --- Storage -------------------------------------------------------------------

  LogEntry _add(
    LogEntryType type, {
    required String title,
    required String detail,
    Map<String, dynamic>? data,
  }) {
    final entry = LogEntry(
      id: _uuid.v4(),
      timestamp: _clock(),
      type: type,
      title: title,
      detail: detail,
      data: data,
    );
    _entries.add(entry);
    // Write in the background: the UI never waits for storage. A failed
    // write keeps the entry in memory (the demo goes on).
    unawaited(
      _store
          .add(entry.toJson())
          .catchError(
            (Object e) => debugPrint('Mission log: write failed: $e'),
          ),
    );
    _trim();
    _changed();
    return entry;
  }

  /// Keeps at most [LogConstants.maxEntries] (drops the oldest).
  void _trim() {
    final extra = _entries.length - LogConstants.maxEntries;
    if (extra <= 0) return;
    final removed = _entries.sublist(0, extra).map((e) => e.id).toList();
    _entries.removeRange(0, extra);
    unawaited(
      _store
          .removeIds(removed)
          .catchError((Object e) => debugPrint('Mission log: trim failed: $e')),
    );
  }

  void _changed() {
    if (_disposed) return;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _engine.removeListener(_onEngine);
    _telemetry.removeListener(_onTelemetry);
    super.dispose();
  }
}
