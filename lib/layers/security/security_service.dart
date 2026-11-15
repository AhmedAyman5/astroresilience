import 'dart:async';

import 'package:flutter/foundation.dart';

import '../log/mission_log_controller.dart';
import 'encrypted_log_store.dart';
import 'log_store.dart';

/// How the local data is kept.
enum StorageMode {
  /// AES-256 encrypted Hive box, key in secure storage. Survives restarts.
  encrypted,

  /// Fallback when secure storage is not available: RAM only, nothing saved.
  memoryOnly;

  String get code => switch (this) {
    StorageMode.encrypted => 'ENCRYPTED',
    StorageMode.memoryOnly => 'MEMORY_ONLY',
  };
}

/// Result of opening the store at start-up.
typedef OpenedStore = ({LogStore store, String? error});

/// Opens the encrypted store, or falls back to memory if anything fails or
/// takes too long. Start-up must never crash or hang (e.g. a browser that
/// blocks storage, or a private window).
Future<OpenedStore> openLogStore({
  Duration timeout = SecurityService.openTimeout,
  Future<LogStore> Function()? opener,
}) async {
  try {
    final store = await (opener ?? EncryptedLogStore.open)().timeout(timeout);
    return (store: store, error: null);
  } catch (e) {
    debugPrint('Secure storage unavailable, using memory only: $e');
    return (store: InMemoryLogStore(), error: e.toString());
  }
}

/// Layer 5 state for the UI: encryption mode, stored entry count, and the
/// "Wipe local data" action.
class SecurityService extends ChangeNotifier {
  SecurityService({
    required this._store,
    required MissionLogController log,
    this.openError,
  }) : _log = log {
    log.addListener(_refreshCount);
    _refreshCount();
  }

  /// Max wait for the encrypted store at start-up.
  static const Duration openTimeout = Duration(seconds: 5);

  /// Shown in the UI and the export.
  static const String algorithm = 'AES-256';

  final LogStore _store;
  final MissionLogController _log;

  /// Why the encrypted store could not be opened (null if it was).
  final String? openError;

  int _storedCount = 0;
  bool _wiping = false;
  bool _disposed = false;

  StorageMode get mode =>
      _store.isPersistent ? StorageMode.encrypted : StorageMode.memoryOnly;
  bool get isEncrypted => mode == StorageMode.encrypted;

  /// Entries currently in the store.
  int get storedCount => _storedCount;
  bool get isWiping => _wiping;

  /// Short label for chips and the export, e.g. "AES-256 · ON DEVICE".
  String get storageLabel =>
      isEncrypted ? '$algorithm · ON DEVICE' : 'MEMORY ONLY';

  /// Deletes the Mission Log, the meal history and therefore the learned
  /// food preferences (they are computed from the meal history). The app
  /// keeps running; telemetry and the engine are not touched.
  Future<void> wipeLocalData() async {
    _wiping = true;
    notifyListeners();
    try {
      await _log.clearAll();
    } finally {
      _wiping = false;
      await _refreshCountNow();
    }
  }

  void _refreshCount() => unawaited(_refreshCountNow());

  Future<void> _refreshCountNow() async {
    try {
      _storedCount = await _store.count();
    } catch (_) {
      _storedCount = _log.length;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _log.removeListener(_refreshCount);
    super.dispose();
  }
}
