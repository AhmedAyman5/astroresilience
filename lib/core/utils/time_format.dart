/// Small helpers to format times the same way everywhere.
class TimeFormat {
  TimeFormat._();

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// ISO 8601 without milliseconds, e.g. "2026-11-14T10:30:00".
  /// This is the exact format required for the telemetry JSON.
  static String isoSeconds(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
      'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  /// Clock time for the UI, e.g. "10:30:05".
  static String clock(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}
