import 'package:flutter/foundation.dart';

/// Kind of Mission Log entry.
/// - status: the overall alert level changed (NOMINAL / WATCH / WARNING / CRITICAL)
/// - prediction: a risk appeared or got more serious
/// - meal: the astronaut logged a meal
/// - system: simulator events (scenario / source change, session reset, wipe)
enum LogEntryType {
  status,
  prediction,
  meal,
  system;

  String get code => name.toUpperCase();

  String get label => switch (this) {
    LogEntryType.status => 'Status',
    LogEntryType.prediction => 'Prediction',
    LogEntryType.meal => 'Meal',
    LogEntryType.system => 'System',
  };

  static LogEntryType fromCode(String code) => LogEntryType.values.firstWhere(
    (t) => t.code == code,
    orElse: () => LogEntryType.system,
  );
}

/// One line of the Mission Log. Stored as a plain JSON map (no Hive
/// TypeAdapters, no code generation), so any storage can keep it.
@immutable
class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.detail,
    this.data,
  });

  /// Unique id (uuid v4). Also the key in the encrypted box.
  final String id;
  final DateTime timestamp;
  final LogEntryType type;

  /// Short headline, e.g. "Status → WARNING".
  final String title;

  /// One explaining sentence.
  final String detail;

  /// Optional structured details (risk score, why list, food id, % eaten…).
  /// Kept as JSON-friendly values so export is a plain jsonEncode.
  final Map<String, dynamic>? data;

  LogEntry copyWith({
    String? id,
    DateTime? timestamp,
    LogEntryType? type,
    String? title,
    String? detail,
    Map<String, dynamic>? data,
  }) {
    return LogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      data: data ?? this.data,
    );
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return LogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: LogEntryType.fromCode(json['type'] as String),
      title: json['title'] as String,
      detail: (json['detail'] as String?) ?? '',
      data: data == null ? null : Map<String, dynamic>.from(data as Map),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    // Full ISO 8601 with milliseconds, so entries logged in the same second
    // keep their order after a reload.
    'timestamp': timestamp.toIso8601String(),
    'type': type.code,
    'title': title,
    'detail': detail,
    if (data != null) 'data': data,
  };
}
