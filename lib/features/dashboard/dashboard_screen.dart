import 'package:flutter/material.dart';

import 'engine_debug_view.dart';

/// Tab 1 — Mission Dashboard.
/// Phase 2: shows a temporary engine debug view. The real dashboard (risk
/// gauge, vital cards, prediction card) arrives in Phase 3.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const EngineDebugView();
}
