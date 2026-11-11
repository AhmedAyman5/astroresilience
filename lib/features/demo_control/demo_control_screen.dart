import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_panel.dart';

/// Demo Control — opened from the top-bar icon. Placeholder until Phase 5.
class DemoControlScreen extends StatelessWidget {
  const DemoControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Control')),
      body: const PlaceholderPanel(
        icon: Icons.tune,
        title: 'Demo Control',
        subtitle: 'Drive the live demo for the judges.',
        phase: 'PHASE 5',
        modules: [
          'Scenario selector (Nominal, Fatigue, Hypoxia…)',
          'Data source: Simulated / NASA Replay',
          'Interval: 2 / 5 / 10 s and reset session',
          'Security status and wipe local data',
          'About: 5-layer architecture',
        ],
      ),
    );
  }
}
