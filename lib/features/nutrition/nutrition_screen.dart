import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_panel.dart';

/// Tab 3 — Predictive Nutrition. Placeholder until Phase 4.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPanel(
      icon: Icons.restaurant,
      title: 'Nutrition',
      subtitle: 'Meals recommended from predicted risks.',
      phase: 'PHASE 4',
      modules: [
        'Active recommendations with reasons',
        'Space food cards with macros',
        'Log a meal at 100 / 75 / 50 / 25 %',
        'Energy balance bar and searchable food list',
      ],
    );
  }
}
