import 'dart:convert';

import '../../core/constants/telemetry_constants.dart';
import '../../core/models/vital_reading.dart';

/// Result of parsing a replay file.
class ReplayParseResult {
  const ReplayParseResult(this.readings, this.skipped);

  final List<VitalReading> readings;

  /// Number of rows that were bad and therefore skipped.
  final int skipped;
}

/// Tolerant parser for external data files (NASA datasets, CSV exports...).
///
/// Real-world files are messy, so this parser:
/// - accepts a JSON array, a JSON object with a "readings"/"data" array, or CSV
///   (comma, semicolon or tab separated);
/// - maps common column names (e.g. "HR", "pulse", "SpO2 %", "skin_temp") to
///   our fields — names are compared lower-case without spaces/underscores;
/// - converts °F to °C and SpO2 fractions (0.97) to percent;
/// - SKIPS any row that is missing a vital or has impossible values, instead
///   of crashing the replay.
class ReplayParser {
  ReplayParser._();

  /// Our field → accepted column names (already normalized).
  static const Map<String, List<String>> _aliases = {
    'timestamp': ['timestamp', 'time', 'datetime', 'date', 'ts', 'utc'],
    'heart_rate': [
      'heartrate', 'hr', 'pulse', 'pulserate', 'bpm', 'heartratebpm', 'hrbpm',
    ],
    'hrv': ['hrv', 'hrvms', 'rmssd', 'hrvrmssd', 'heartratevariability', 'sdnn'],
    'spo2': [
      'spo2', 'sp02', 'spo2pct', 'spo2percent', 'oxygensaturation', 'o2sat',
      'sao2', 'saturation',
    ],
    'temperature': [
      'temperature', 'temp', 'tempc', 'skintemp', 'skintemperature',
      'bodytemp', 'bodytemperature', 'temperaturec',
    ],
    'activity': ['activity', 'activitylevel', 'intensity', 'exertion'],
  };

  /// Detects the format from the content and parses it.
  static ReplayParseResult parse(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      return parseJson(content);
    }
    return parseCsv(content);
  }

  static ReplayParseResult parseJson(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return const ReplayParseResult([], 0);
    }
    if (decoded is Map) {
      decoded = decoded['readings'] ?? decoded['data'] ?? decoded['records'];
    }
    if (decoded is! List) return const ReplayParseResult([], 0);

    final readings = <VitalReading>[];
    var skipped = 0;
    for (final row in decoded) {
      final reading = row is Map ? rowToReading(row) : null;
      if (reading == null) {
        skipped++;
      } else {
        readings.add(reading);
      }
    }
    return ReplayParseResult(readings, skipped);
  }

  static ReplayParseResult parseCsv(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) return const ReplayParseResult([], 0);

    final delimiter = _detectDelimiter(lines.first);
    final header = _splitCsvLine(lines.first, delimiter);

    final readings = <VitalReading>[];
    var skipped = 0;
    for (final line in lines.skip(1)) {
      final cells = _splitCsvLine(line, delimiter);
      final row = <String, Object?>{
        for (var i = 0; i < header.length && i < cells.length; i++)
          header[i]: cells[i],
      };
      final reading = rowToReading(row);
      if (reading == null) {
        skipped++;
      } else {
        readings.add(reading);
      }
    }
    return ReplayParseResult(readings, skipped);
  }

  /// Converts one row (any column names) into a reading, or null if bad.
  static VitalReading? rowToReading(Map<dynamic, dynamic> row) {
    final fields = <String, Object?>{};
    row.forEach((key, value) {
      final field = _fieldFor(key.toString());
      if (field != null && !fields.containsKey(field)) fields[field] = value;
    });

    final hr = _number(fields['heart_rate']);
    final hrv = _number(fields['hrv']);
    var spo2 = _number(fields['spo2']);
    var temp = _number(fields['temperature']);
    if (hr == null || hrv == null || spo2 == null || temp == null) return null;

    // SpO2 given as a fraction (0.97) → percent.
    if (spo2 <= 1.0) spo2 *= 100;
    // Temperature in Fahrenheit → Celsius.
    if (temp > TelemetryConstants.fahrenheitGuess) temp = (temp - 32) * 5 / 9;

    final valid =
        hr >= TelemetryConstants.validHrMin &&
        hr <= TelemetryConstants.validHrMax &&
        hrv >= TelemetryConstants.validHrvMin &&
        hrv <= TelemetryConstants.validHrvMax &&
        spo2 >= TelemetryConstants.validSpo2Min &&
        spo2 <= TelemetryConstants.validSpo2Max &&
        temp >= TelemetryConstants.validTempMin &&
        temp <= TelemetryConstants.validTempMax;
    if (!valid) return null;

    return VitalReading(
      timestamp: _timestamp(fields['timestamp']),
      heartRate: hr.round(),
      hrv: hrv.round(),
      spo2: spo2.round(),
      temperature: VitalReading.roundTemperature(temp),
      activity: _activity(fields['activity']),
    );
  }

  /// Lower-case, keep only letters and digits: "Heart Rate (bpm)" → "heartratebpm".
  static String _normalize(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _fieldFor(String key) {
    final normalized = _normalize(key);
    for (final entry in _aliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// Missing or unreadable timestamps are fine: the replay re-stamps every
  /// reading with the current time anyway.
  static DateTime _timestamp(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    final n = _number(value);
    if (n != null) {
      // Large numbers are epoch milliseconds, smaller ones epoch seconds.
      const millisThreshold = 1e12;
      return DateTime.fromMillisecondsSinceEpoch(
        (n > millisThreshold ? n : n * 1000).round(),
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Accepts words (low / medium / vigorous...), indexes 0/1/2, or METs.
  static ActivityLevel _activity(Object? value) {
    if (value is String) {
      final text = value.trim().toLowerCase();
      const low = ['low', 'rest', 'resting', 'sedentary', 'light', 'none'];
      const moderate = ['moderate', 'medium', 'mid'];
      const high = ['high', 'vigorous', 'intense', 'heavy'];
      if (low.contains(text)) return ActivityLevel.low;
      if (moderate.contains(text)) return ActivityLevel.moderate;
      if (high.contains(text)) return ActivityLevel.high;
    }
    final n = _number(value);
    if (n == null) return ActivityLevel.low;
    // 0 / 1 / 2 = index of the level.
    if (n == 0 || n == 1 || n == 2) return ActivityLevel.values[n.toInt()];
    // Otherwise assume METs: 3–6 moderate, 6+ vigorous (standard cut-offs).
    const moderateMets = 3.0;
    const highMets = 6.0;
    if (n >= highMets) return ActivityLevel.high;
    if (n >= moderateMets) return ActivityLevel.moderate;
    return ActivityLevel.low;
  }

  static String _detectDelimiter(String header) {
    const candidates = [',', ';', '\t'];
    var best = ',';
    var bestCount = 0;
    for (final c in candidates) {
      final count = c.allMatches(header).length;
      if (count > bestCount) {
        best = c;
        bestCount = count;
      }
    }
    return best;
  }

  /// Splits a CSV line, respecting simple "quoted, values".
  static List<String> _splitCsvLine(String line, String delimiter) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delimiter && !inQuotes) {
        out.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    out.add(buffer.toString().trim());
    return out;
  }
}
