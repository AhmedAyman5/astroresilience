/// Layer 5 storage interface for the Mission Log (and therefore the meal
/// history, which is made of the log's meal entries).
///
/// Entries are plain JSON maps — no Hive TypeAdapters, no code generation —
/// so the same data can live in memory (tests, fallback) or in the
/// AES-256 encrypted Hive box (EncryptedLogStore) without changes elsewhere.
///
/// The app creates its store in ONE place only: main.dart.
abstract class LogStore {
  /// True when the data is encrypted and survives an app restart.
  bool get isPersistent;

  /// Every stored entry (any order; the caller sorts by timestamp).
  Future<List<Map<String, dynamic>>> loadAll();

  /// Stores one entry. Its 'id' field is the key.
  Future<void> add(Map<String, dynamic> entry);

  /// Removes entries by id (used to keep the log at its max size).
  Future<void> removeIds(Iterable<String> ids);

  /// Deletes everything ("Wipe local data").
  Future<void> clearAll();

  /// Number of stored entries.
  Future<int> count();
}

/// Keeps entries in RAM only. Used by the tests (no plugins needed) and as
/// the safe fallback when the encrypted store cannot be opened: the app then
/// still works, it just forgets the log when it is closed.
class InMemoryLogStore implements LogStore {
  final Map<String, Map<String, dynamic>> _entries = {};

  @override
  bool get isPersistent => false;

  @override
  Future<List<Map<String, dynamic>>> loadAll() async =>
      _entries.values.map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Future<void> add(Map<String, dynamic> entry) async {
    _entries[entry['id'] as String] = Map<String, dynamic>.from(entry);
  }

  @override
  Future<void> removeIds(Iterable<String> ids) async {
    for (final id in ids) {
      _entries.remove(id);
    }
  }

  @override
  Future<void> clearAll() async => _entries.clear();

  @override
  Future<int> count() async => _entries.length;
}
