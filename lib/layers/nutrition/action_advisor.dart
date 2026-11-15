import '../../core/models/engine_result.dart';

/// Kind of non-food action (the UI picks an icon for each).
enum ActionKind { rest, hydrate, reduceActivity, breathing, routine }

/// A non-food recommendation shown next to the meals.
class RecoveryAction {
  const RecoveryAction({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final ActionKind kind;

  /// Short imperative, e.g. "Rest for 20 minutes".
  final String title;

  /// One sentence explaining why.
  final String detail;
}

/// Layer 3 (part): picks the non-food action for a risk.
///
/// The spec says every recommendation must include something the astronaut
/// can DO besides eating (rest, reduce activity, hydrate, breathing). Phase 4
/// adds the ranked foods; this advisor already gives the action.
class ActionAdvisor {
  ActionAdvisor._();

  /// Shown when nothing is predicted.
  static const RecoveryAction routine = RecoveryAction(
    kind: ActionKind.routine,
    title: 'Keep the current routine',
    detail:
        'Vitals are inside the personal baseline. Follow the planned menu '
        'and drink water regularly.',
  );

  /// Action for the most serious prediction (or [routine] if none).
  static RecoveryAction forPrediction(RiskPrediction? p) {
    if (p == null) return routine;
    final urgent = p.severity == PredictionSeverity.critical;
    return switch (p.type) {
      RiskType.fatigue => RecoveryAction(
        kind: ActionKind.reduceActivity,
        title: urgent
            ? 'Stop exercise and rest now'
            : 'Reduce activity and rest 20 min',
        detail:
            'Heart rate is high and HRV is falling during sustained effort. '
            'Lower the workload to let the body recover.',
      ),
      RiskType.physiologicalStress => const RecoveryAction(
        kind: ActionKind.breathing,
        title: 'Breathing protocol: 4-7-8 for 5 min',
        detail:
            'Heart rate is up while resting and HRV is low: a stress '
            'response. Slow breathing calms the nervous system.',
      ),
      RiskType.hypoxia => RecoveryAction(
        kind: ActionKind.rest,
        title: urgent
            ? 'Stop all activity, check O2 supply'
            : 'Rest and check cabin O2 levels',
        detail:
            'Blood oxygen is dropping. Resting lowers oxygen demand while the '
            'cabin atmosphere is checked.',
      ),
      RiskType.thermalStress => const RecoveryAction(
        kind: ActionKind.hydrate,
        title: 'Hydrate and cool down',
        detail:
            'Skin temperature stays high. Drink 500 ml of water with '
            'electrolytes and check suit or cabin cooling.',
      ),
      RiskType.nutritionDeficit => const RecoveryAction(
        kind: ActionKind.reduceActivity,
        title: 'Eat a meal before more work',
        detail:
            'Energy burned is well above energy eaten. Pause heavy tasks '
            'until a meal is logged.',
      ),
    };
  }
}
