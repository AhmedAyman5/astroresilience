import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_panel.dart';

/// Tab 1 — Mission Dashboard. Placeholder until Phase 3.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPanel(
      icon: Icons.space_dashboard,
      title: 'Mission Dashboard',
      subtitle: 'Live risk overview for the astronaut.',
      phase: 'PHASE 3',
      modules: [
        'Risk gauge 0–100 with status label',
        '5 vital cards with sparkline and trend arrow',
        'Top prediction card with expandable "Why?"',
        'Recommended action linking to Nutrition',
      ],
    );
  }
}
