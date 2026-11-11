import 'package:flutter/services.dart';

import '../../core/constants/telemetry_constants.dart';
import '../../core/models/vital_reading.dart';
import 'replay_parser.dart';
import 'telemetry_source.dart';

/// Thrown when no usable replay data could be loaded.
class ReplayException implements Exception {
  const ReplayException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Replays real (NASA) data from assets/data/nasa/ at the chosen interval.
///
/// - Any .json or .csv file the team drops in that folder is used
///   automatically (real data first, otherwise the bundled sample file).
/// - Bad rows are skipped (see ReplayParser).
/// - Readings are re-stamped with the current time, so the timeline, charts
///   and trend math stay consistent with live data.
/// - When the file ends, the replay loops from the start.
class ReplaySource extends TelemetrySource {
  ReplaySource({AssetBundle? bundle, this.assetPath})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Force a specific file. If null, the folder is scanned.
  final String? assetPath;

  List<VitalReading> _readings = const [];
  int _index = 0;

  /// File actually loaded, rows skipped as bad, total readings.
  String? loadedAsset;
  int skippedRows = 0;
  int get length => _readings.length;

  /// Position in the file (for the UI: "row 12 / 60").
  int get position => _readings.isEmpty ? 0 : _index % _readings.length;

  bool get isLoaded => _readings.isNotEmpty;

  @override
  String get label => 'NASA Replay';

  @override
  Future<void> prepare() async {
    if (isLoaded) return;
    final path = assetPath ?? await _findReplayFile();
    final content = await _bundle.loadString(path);
    final result = ReplayParser.parse(content);
    if (result.readings.isEmpty) {
      throw ReplayException('No valid readings in $path');
    }
    _readings = result.readings;
    skippedRows = result.skipped;
    loadedAsset = path;
    _index = 0;
  }

  /// Prefers a real data file over the bundled sample.
  Future<String> _findReplayFile() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final files =
          manifest
              .listAssets()
              .where((a) => a.startsWith(TelemetryConstants.replayFolder))
              .where((a) => a.endsWith('.json') || a.endsWith('.csv'))
              .toList()
            ..sort();
      final real = files.where(
        (a) => a != TelemetryConstants.sampleReplayAsset,
      );
      if (real.isNotEmpty) return real.first;
    } catch (_) {
      // No manifest (e.g. in tests): fall back to the sample file.
    }
    return TelemetryConstants.sampleReplayAsset;
  }

  @override
  VitalReading? next(DateTime now, Duration interval) {
    if (_readings.isEmpty) return null;
    final reading = _readings[_index % _readings.length];
    _index++;
    return reading.copyWith(timestamp: now);
  }

  @override
  void reset() => _index = 0;
}
