import '../models/engine_result.dart';

/// A NASA Human Research Program context for one risk type.
class HazardLink {
  const HazardLink({
    required this.hazard,
    required this.shortName,
    required this.hrpRisk,
  });

  /// One of NASA's "5 Hazards of Human Spaceflight".
  final String hazard;

  /// Short name for the small chip, e.g. "CLOSED ENVIRONMENT".
  final String shortName;

  /// A related risk title from NASA HRP "Risks of Human Spaceflight".
  final String hrpRisk;
}

/// RELATED NASA context for each risk the engine predicts.
///
/// IMPORTANT: these are "related" links we chose to explain WHY each risk
/// matters on a long mission. They are NOT an official NASA classification
/// of the app's predictions, and the app is not a NASA product.
/// Sources (articles, read offline, nothing is fetched): NASA HRP
/// "5 Hazards of Human Spaceflight" and "Risks of Human Spaceflight".
class HazardConstants {
  HazardConstants._();

  static const Map<RiskType, HazardLink> related = {
    RiskType.fatigue: HazardLink(
      hazard: 'Hostile/Closed Environment',
      shortName: 'CLOSED ENVIRONMENT',
      hrpRisk: 'Inadequate Sleep and Irregular Schedules',
    ),
    RiskType.physiologicalStress: HazardLink(
      hazard: 'Isolation & Confinement',
      shortName: 'ISOLATION',
      hrpRisk: 'Behavioral Changes and Psychiatric Disorders',
    ),
    RiskType.hypoxia: HazardLink(
      hazard: 'Hostile/Closed Environment',
      shortName: 'CLOSED ENVIRONMENT',
      hrpRisk: 'Reduced Crew Health and Performance Due to Hypobaric Hypoxia',
    ),
    RiskType.thermalStress: HazardLink(
      hazard: 'Hostile/Closed Environment',
      shortName: 'CLOSED ENVIRONMENT',
      hrpRisk: 'EVA Risk (suit cooling)',
    ),
    RiskType.nutritionDeficit: HazardLink(
      hazard: 'Hostile/Closed Environment',
      shortName: 'CLOSED ENVIRONMENT',
      hrpRisk: 'Inadequate Food and Nutrition',
    ),
  };

  /// App-wide: why the whole system runs on the edge.
  static const String distanceHazard = 'Distance from Earth';
  static const String distanceReason =
      'Earth-link delay of 4–24 minutes each way means the crew cannot wait '
      'for ground support, so monitoring and advice run on the device.';

  static HazardLink of(RiskType type) => related[type]!;
}
