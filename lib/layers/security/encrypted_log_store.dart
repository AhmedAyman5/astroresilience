import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'log_store.dart';

/// Layer 5: the Mission Log (status changes, predictions, meals) stored ON
/// THE DEVICE, encrypted with AES-256.
///
/// HOW IT IS PROTECTED
/// - Hive box opened with HiveAesCipher → every entry is AES-256 encrypted
///   before it is written (IndexedDB on web, a file on Android).
/// - The 256-bit key is generated once with Hive.generateSecureKey() (a
///   cryptographically secure random generator) and kept in
///   flutter_secure_storage: the Android Keystore on Android, WebCrypto-
///   wrapped storage on web. The key is never in the code or the box.
/// - Entries are stored as JSON strings keyed by their id: no TypeAdapters,
///   no code generation, easy to export.
///
/// Nothing here touches the network.
class EncryptedLogStore implements LogStore {
  EncryptedLogStore._(this._box);

  final Box<String> _box;

  static const String boxName = 'mission_log_secure';
  static const String keyName = 'astroresilience_log_key_v1';

  /// Opens (or creates) the encrypted box. Throws if the platform cannot
  /// provide secure storage; main.dart then falls back to memory only.
  static Future<EncryptedLogStore> open({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) async {
    await Hive.initFlutter();
    final key = await _loadOrCreateKey(secureStorage);
    final box = await Hive.openBox<String>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    return EncryptedLogStore._(box);
  }

  /// Reads the key back, or creates it the very first time.
  static Future<List<int>> _loadOrCreateKey(FlutterSecureStorage s) async {
    final stored = await s.read(key: keyName);
    if (stored != null) return base64Decode(stored);
    final key = Hive.generateSecureKey(); // 32 random bytes = AES-256
    await s.write(key: keyName, value: base64Encode(key));
    return key;
  }

  @override
  bool get isPersistent => true;

  @override
  Future<List<Map<String, dynamic>>> loadAll() async {
    final out = <Map<String, dynamic>>[];
    for (final raw in _box.values) {
      try {
        out.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A damaged entry is skipped, never a crash.
      }
    }
    return out;
  }

  @override
  Future<void> add(Map<String, dynamic> entry) =>
      _box.put(entry['id'] as String, jsonEncode(entry));

  @override
  Future<void> removeIds(Iterable<String> ids) => _box.deleteAll(ids);

  /// Wipe. The KEY IS KEPT on purpose: after clear() the box holds no data,
  /// so the old key protects nothing that could leak. Rotating it would mean
  /// closing and re-creating the box during a live demo (more ways to fail)
  /// for no gain. A full reset of the key happens if the app is uninstalled
  /// (Android) or the site data is cleared (web).
  @override
  Future<void> clearAll() async {
    await _box.clear();
    await _box.compact(); // also drop the old encrypted frames from disk
  }

  @override
  Future<int> count() async => _box.length;
}
