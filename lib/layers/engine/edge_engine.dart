import 'dart:math';

import '../../core/constants/engine_constants.dart';
import '../../core/constants/thresholds.dart';
import '../../core/models/engine_result.dart';
import '../../core/models/vital_reading.dart';
import '../../core/utils/stats.dart';
import 'adaptive_baseline.dart';
import 'risk_scoring.dart';
import 'trend_analyzer.dart';

/// One reading in the rolling window, plus the energy deficit at that time.
class EngineSample {
  const EngineSample(this.reading, this.energyDeficitKcal);
  final VitalReading reading;
  final double energyDeficitKcal;
}

/// Verdict of one rule before it becomes a [RiskPrediction].
class _RuleOutput {
  const _RuleOutput({
    required this.type,
    required this.level,
    required this.rawLevel,
    required this.scale,
    required this.series,
    required this.current,
    required this.agreement,
    required this.why,
  });

  final RiskType type;

  /// Final level after combining the supporting signals.
  final double level;

  /// Level of the main metric alone (used to pick the next threshold).
  final double rawLevel;
  final MetricScale scale;

  /// Main metric for each reading in the window (for trend and persistence).
  final List<double> series;

  /// Smoothed current value of the main metric.
  final double current;

  /// 1.0 = all supporting signals present, 0.5 = only some.
  final double agreement;
  final List<String> why;
}

/// Layer 2 — the Edge AI Engine. Rule-based and fully explainable: every
/// prediction says WHICH signals triggered it, so the astronaut (and the
/// judges) can check the reasoning without any black box.
///
/// For every new reading it:
/// 1. adds the reading to a rolling window of the last 12 readings;
/// 2. runs the 5 combined rules (fatigue, physiological stress, hypoxia,
///    thermal stress, nutrition deficit), each giving a severity level;
/// 3. measures each risk's trend with a straight-line fit over the window and
///    estimates the minutes until the next threshold;
/// 4. turns the levels into a weighted 0–100 risk score and a status;
/// 5. updates the personal baseline if the reading was calm (learning).
///
/// Pure Dart (no Flutter, no timers), so it is easy to unit test.
class EdgeEngine {
  EdgeEngine({AdaptiveBaseline? baseline})
    : baseline = baseline ?? AdaptiveBaseline();

  final AdaptiveBaseline baseline;
  final List<EngineSample> _window = [];

  List<EngineSample> get window => List.unmodifiable(_window);

  // Metric scales built from core/constants/thresholds.dart.
  static final MetricScale spo2Scale = MetricScale(
    approach: Thresholds.spo2Approach.toDouble(),
    warning: Thresholds.spo2Warning.toDouble(),
    critical: Thresholds.spo2Critical.toDouble(),
  );
  static final MetricScale hrRestScale = MetricScale(
    approach: Thresholds.hrRestApproach.toDouble(),
    warning: Thresholds.hrRestWarning.toDouble(),
    critical: Thresholds.hrRestCritical.toDouble(),
  );
  static const MetricScale hrvDropScale = MetricScale(
    approach: Thresholds.hrvDropApproach,
    warning: Thresholds.hrvDropWarning,
    critical: Thresholds.hrvDropCritical,
  );
  static const MetricScale tempScale = MetricScale(
    approach: Thresholds.tempApproach,
    warning: Thresholds.tempWarning,
    critical: Thresholds.tempCritical,
  );
  static final MetricScale energyScale = MetricScale(
    approach: Thresholds.energyDeficitApproach.toDouble(),
    warning: Thresholds.energyDeficitWarning.toDouble(),
    critical: Thresholds.energyDeficitCritical.toDouble(),
  );

  /// Processes one new reading and returns the full engine verdict.
  EngineResult process(VitalReading reading, {double energyDeficitKcal = 0}) {
    _window.add(EngineSample(reading, energyDeficitKcal));
    if (_window.length > EngineConstants.windowSize) _window.removeAt(0);

    // Rules use the baseline as it was BEFORE this reading.
    final rules = [
      _fatigue(),
      _physiologicalStress(),
      _hypoxia(),
      _thermalStress(),
      _nutritionDeficit(),
    ].nonNulls.toList();

    final score = RiskScoring.combinedScore({
      for (final r in rules) r.type: r.level,
    });
    final predictions = rules.map(_toPrediction).nonNulls.toList()
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    // Learning step: only calm readings update the personal baseline.
    final learned = baseline.update(reading);

    return EngineResult(
      timestamp: reading.timestamp,
      reading: reading,
      riskScore: score,
      status: RiskScoring.statusForScore(score),
      predictions: predictions,
      baselineHeartRate: baseline.heartRate,
      baselineHrv: baseline.hrv,
      baselineUpdated: learned,
      energyDeficitKcal: energyDeficitKcal,
      windowSize: _window.length,
    );
  }

  /// Clears the window and the learned baseline (new session).
  void reset() {
    _window.clear();
    baseline.reset();
  }

  // --- Series helpers ----------------------------------------------------------

  List<double> get _hrs => [
    for (final s in _window) s.reading.heartRate.toDouble(),
  ];
  List<double> get _hrvs => [for (final s in _window) s.reading.hrv.toDouble()];
  List<double> get _hrvDrops => [
    for (final s in _window) baseline.hrvDrop(s.reading.hrv),
  ];
  List<double> get _spo2s => [
    for (final s in _window) s.reading.spo2.toDouble(),
  ];
  List<double> get _temps => [for (final s in _window) s.reading.temperature];
  List<double> get _deficits => [
    for (final s in _window) s.energyDeficitKcal,
  ];

  static double _smooth(List<double> series) =>
      meanOfLast(series, EngineConstants.smoothingReadings);

  static int _pct(double fraction) => (fraction * 100).round();

  bool get _hrElevated =>
      _smooth(_hrs) >= baseline.heartRate * (1 + Thresholds.hrElevatedRatio);

  int get _hrAboveBaselinePct =>
      _pct(_smooth(_hrs) / baseline.heartRate - 1);

  // --- The 5 combined rules ----------------------------------------------------

  /// FATIGUE = low HRV + high HR + high activity.
  /// Main metric: HRV drop vs personal baseline. Needs at least one of
  /// "high HR" / "sustained high activity"; with only one, severity is one
  /// notch lower.
  _RuleOutput? _fatigue() {
    final drops = _hrvDrops;
    final drop = _smooth(drops);
    final hr = _smooth(_hrs);
    final recent = _window.sublist(
      max(0, _window.length - Thresholds.fatigueRecentReadings),
    );
    final highCount = recent
        .where((s) => s.reading.activity == ActivityLevel.high)
        .length;
    final hrHigh = hr >= Thresholds.fatigueHrHigh;
    final exertion = highCount >= Thresholds.fatigueMinHighActivityReadings;
    if (!hrHigh && !exertion) return null;

    final allSignals = hrHigh && exertion;
    final raw = hrvDropScale.level(drop);
    return _RuleOutput(
      type: RiskType.fatigue,
      level: raw * (allSignals ? 1 : EngineConstants.singleSignalFactor),
      rawLevel: raw,
      scale: hrvDropScale,
      series: drops,
      current: drop,
      agreement: allSignals
          ? EngineConstants.fullAgreement
          : EngineConstants.partialAgreement,
      why: [
        if (drop > 0)
          'HRV ${_smooth(_hrvs).round()} ms is ${_pct(drop)}% below your '
              'baseline of ${baseline.hrv.round()} ms',
        if (hrHigh)
          'Heart rate ${hr.round()} bpm during exertion '
              '(high: ${Thresholds.fatigueHrHigh}+ bpm)',
        if (exertion)
          'High activity in $highCount of the last ${recent.length} readings',
      ],
    );
  }

  /// PHYSIOLOGICAL_STRESS = high HR at LOW activity + low HRV.
  /// The heart is racing although the astronaut is resting.
  _RuleOutput? _physiologicalStress() {
    if (_window.last.reading.activity != ActivityLevel.low) return null;
    final hrs = _hrs;
    final hr = _smooth(hrs);
    final drop = _smooth(_hrvDrops);
    final hrvLow = drop >= Thresholds.hrvDropWarning;
    final raw = hrRestScale.level(hr);
    return _RuleOutput(
      type: RiskType.physiologicalStress,
      level: raw * (hrvLow ? 1 : EngineConstants.singleSignalFactor),
      rawLevel: raw,
      scale: hrRestScale,
      series: hrs,
      current: hr,
      agreement: hrvLow
          ? EngineConstants.fullAgreement
          : EngineConstants.partialAgreement,
      why: [
        'Heart rate ${hr.round()} bpm at rest '
            '(warning over ${Thresholds.hrRestWarning} bpm)',
        if (hrvLow)
          'HRV ${_smooth(_hrvs).round()} ms, ${_pct(drop)}% below your baseline',
        'Activity is low, so exercise does not explain the heart rate',
      ],
    );
  }

  /// HYPOXIA = SpO2 under threshold. A raised heart rate (the body
  /// compensating) increases confidence.
  _RuleOutput? _hypoxia() {
    final spo2s = _spo2s;
    final spo2 = _smooth(spo2s);
    final compensating = _hrElevated;
    final raw = spo2Scale.level(spo2);
    return _RuleOutput(
      type: RiskType.hypoxia,
      level: raw,
      rawLevel: raw,
      scale: spo2Scale,
      series: spo2s,
      current: spo2,
      agreement: compensating
          ? EngineConstants.fullAgreement
          : EngineConstants.partialAgreement,
      why: [
        'SpO2 ${spo2.round()}% (warning under ${Thresholds.spo2Warning}%, '
            'critical under ${Thresholds.spo2Critical}%)',
        if (compensating)
          'Heart rate $_hrAboveBaselinePct% above baseline: '
              'the body is compensating',
      ],
    );
  }

  /// THERMAL_STRESS = high temperature SUSTAINED for 3+ readings.
  /// We use the lowest of the last 3 temperatures: all 3 must be high.
  _RuleOutput? _thermalStress() {
    final temps = _temps;
    final n = Thresholds.tempSustainedReadings;
    final last = temps.sublist(max(0, temps.length - n));
    final sustained = last.reduce(min);
    var raw = tempScale.level(sustained);
    // Not enough readings yet to call it "sustained".
    if (temps.length < n) raw = min(raw, EngineConstants.levelBelowWarning);
    final elevated = _hrElevated;
    return _RuleOutput(
      type: RiskType.thermalStress,
      level: raw,
      rawLevel: raw,
      scale: tempScale,
      series: temps,
      current: sustained,
      agreement: elevated
          ? EngineConstants.fullAgreement
          : EngineConstants.partialAgreement,
      why: [
        'Skin temperature at or above ${sustained.toStringAsFixed(1)} °C '
            'for the last ${last.length} readings '
            '(warning over ${Thresholds.tempWarning} °C)',
        if (elevated) 'Heart rate $_hrAboveBaselinePct% above baseline',
      ],
    );
  }

  /// NUTRITION_DEFICIT = energy deficit + fatigue markers (HRV down).
  _RuleOutput? _nutritionDeficit() {
    final deficits = _deficits;
    final deficit = deficits.last;
    final drop = _smooth(_hrvDrops);
    final marker = drop >= Thresholds.nutritionHrvMarker;
    final raw = energyScale.level(deficit);
    final activity = _window.last.reading.activity;
    return _RuleOutput(
      type: RiskType.nutritionDeficit,
      level: raw * (marker ? 1 : EngineConstants.singleSignalFactor),
      rawLevel: raw,
      scale: energyScale,
      series: deficits,
      current: deficit,
      agreement: marker
          ? EngineConstants.fullAgreement
          : EngineConstants.partialAgreement,
      why: [
        'Energy deficit about ${deficit.round()} kcal '
            '(warning over ${Thresholds.energyDeficitWarning} kcal)',
        if (marker) 'Fatigue marker: HRV ${_pct(drop)}% below your baseline',
        if (activity != ActivityLevel.low)
          '${activity.label} activity keeps burning energy',
      ],
    );
  }

  // --- From rule output to prediction ------------------------------------------

  RiskPrediction? _toPrediction(_RuleOutput rule) {
    final times = [for (final s in _window) s.reading.timestamp];
    final trend = TrendAnalyzer.analyze(times, rule.series, rule.scale);

    // Next threshold to watch: warning, or critical if warning is passed.
    int? minutes;
    String? nextThreshold;
    if (trend.trend == RiskTrend.rising) {
      if (rule.rawLevel < EngineConstants.levelWarning) {
        nextThreshold = 'warning';
        minutes = TrendAnalyzer.minutesTo(
          rule.current,
          rule.scale.warning,
          trend.slopePerMinute,
        );
      } else if (rule.rawLevel < EngineConstants.levelCritical) {
        nextThreshold = 'critical';
        minutes = TrendAnalyzer.minutesTo(
          rule.current,
          rule.scale.critical,
          trend.slopePerMinute,
        );
      }
    }

    final active = rule.level >= EngineConstants.levelWarning;
    // WATCH = not there yet, but rising and expected within the horizon.
    final watch =
        !active &&
        trend.trend == RiskTrend.rising &&
        rule.level >= EngineConstants.watchMinLevel &&
        minutes != null &&
        minutes <= EngineConstants.predictionHorizonMinutes;
    if (!active && !watch) return null;

    final fill = _window.length / EngineConstants.windowSize;
    double confidence;
    if (active) {
      final over = rule.series
          .where((v) => rule.scale.level(v) >= EngineConstants.levelWarning)
          .length;
      final persistence = over / rule.series.length;
      confidence =
          100 *
          (EngineConstants.confPersistenceWeight * persistence +
              EngineConstants.confAgreementWeight * rule.agreement +
              EngineConstants.confFillWeight * fill);
    } else {
      confidence = min(
        EngineConstants.confWatchCap,
        100 *
            (EngineConstants.confWatchR2Weight * trend.r2 +
                EngineConstants.confWatchFillWeight * fill),
      );
    }

    return RiskPrediction(
      type: rule.type,
      severity: RiskScoring.severityForLevel(rule.level),
      confidence: confidence.round().clamp(
        EngineConstants.confMin,
        EngineConstants.confMax,
      ),
      trend: trend.trend,
      minutesToThreshold: minutes,
      intensity: rule.level,
      why: [
        ...rule.why,
        if (trend.trend == RiskTrend.rising)
          'Getting worse over the last ${_window.length} readings',
        if (minutes != null && nextThreshold != null)
          'At this rate the $nextThreshold threshold is reached in '
              '~$minutes min',
      ],
    );
  }
}
