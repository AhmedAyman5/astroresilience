import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_panel.dart';

/// Tab 4 — Mission Log. Placeholder until Phase 4.
class MissionLogScreen extends StatelessWidget {
  const MissionLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPanel(
      icon: Icons.receipt_long,
      title: 'Mission Log',
      subtitle: 'Everything the system saw and the astronaut did.',
      phase: 'PHASE 4',
      modules: [
        'Timeline of status changes, predictions and meals',
        'Newest first, with mono timestamps',
        'Export log as JSON with a copy button',
      ],
    );
  }
}
