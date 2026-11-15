import 'package:flutter/material.dart';

import 'app/app.dart';
import 'layers/security/security_service.dart';

/// AstroResilience OS — offline edge health system for astronauts.
/// "It doesn't just monitor — it predicts, recommends, and learns."
///
/// Start-up opens the AES-256 encrypted Mission Log store. This is the ONE
/// place where the store is created. If secure storage fails or is too slow
/// (5 s), the app falls back to memory only: it must never crash or hang.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final opened = await openLogStore();
  runApp(AstroResilienceApp(store: opened.store, storeError: opened.error));
}
