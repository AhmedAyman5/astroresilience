import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_panel.dart';

/// Tab 2 — Vitals charts. Placeholder until Phase 3.
class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPanel(
      icon: Icons.monitor_heart,
      title: 'Vitals',
      subtitle: 'Smart-patch telemetry over time.',
      phase: 'PHASE 3',
      modules: [
        'Heart rate, HRV, SpO2, temperature, activity charts',
        'Dashed threshold lines on every chart',
        'Range toggle: 2 min / 10 min / session',
      ],
    );
  }
}
