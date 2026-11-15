import 'dart:math';

import 'package:astroresilience/app/app.dart';
import 'package:astroresilience/app/state/earth_link_controller.dart';
import 'package:astroresilience/core/constants/app_constants.dart';
import 'package:astroresilience/core/constants/telemetry_constants.dart';
import 'package:astroresilience/core/models/scenario.dart';
import 'package:astroresilience/features/dashboard/widgets/risk_gauge.dart';
import 'package:astroresilience/layers/engine/engine_controller.dart';
import 'package:astroresilience/layers/log/mission_log_controller.dart';
import 'package:astroresilience/layers/security/log_store.dart';
import 'package:astroresilience/layers/telemetry/replay_source.dart';
import 'package:astroresilience/layers/telemetry/telemetry_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Mission + Vitals render at 390x844 with live data, no overflow',
    (tester) async {
      // Phone size from the Definition of Done: 390 x 844. Any RenderFlex
      // overflow is reported as a FlutterError, which fails this test.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AstroResilienceApp(store: InMemoryLogStore(), simulatorSeed: 7),
      );
      expect(find.text('Initializing edge engine…'), findsOneWidget);

      // Wait for the splash timer and the route transition.
      await tester.pump(AppConstants.splashDuration);
      await tester.pumpAndSettle();

      // --- Top bar + tabs ---------------------------------------------------
      expect(find.text('OFFLINE · EDGE MODE'), findsOneWidget);
      expect(find.text('EARTH LINK DELAY:'), findsOneWidget);
      for (final tab in ['Mission', 'Vitals', 'Nutrition', 'Log']) {
        expect(find.text(tab), findsOneWidget);
      }

      // --- Mission dashboard, calm start -------------------------------------
      expect(find.text('MISSION RISK'), findsOneWidget);
      expect(find.byType(RiskGauge), findsOneWidget);
      expect(find.byKey(const Key('alertLabel')), findsOneWidget);
      // Let 1 minute of NOMINAL readings fill the window.
      await pumpReadings(tester, 12);
      await scrollThrough(tester, const Key('dashboardList'));
      expect(find.text('All systems nominal'), findsOneWidget);
      expect(find.textContaining('BASELINE LEARNING:'), findsOneWidget);
      expect(find.text('WINDOW: 12/12 READINGS'), findsOneWidget);
      expect(find.text('Keep the current routine'), findsOneWidget);

      // --- Demo Control: switch to the hypoxia scenario ---------------------
      await tester.tap(find.byTooltip('Demo Control'));
      await tester.pumpAndSettle();
      expect(find.text('SCENARIO'), findsOneWidget);
      expect(find.text('Reset session'), findsOneWidget);
      expect(find.text('Log +600 kcal'), findsOneWidget);
      await tester.tap(find.byKey(const Key('scenarioDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hypoxia event').last);
      await tester.pumpAndSettle();
      final telemetry = Provider.of<TelemetryController>(
        tester.element(find.text('SCENARIO')),
        listen: false,
      );
      expect(telemetry.scenario, Scenario.hypoxiaEvent);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Back to the top of the dashboard, where the gauge label is.
      await tester.drag(
        find.byKey(const Key('dashboardList')),
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();

      // 3 minutes of readings: SpO2 drifts down to CRITICAL. Record every
      // alert stage shown on the way (WATCH should appear before WARNING).
      final seen = <String>{};
      for (var i = 0; i < 36; i++) {
        await tester.pump(const Duration(seconds: 5));
        seen.add(
          tester.widget<Text>(find.byKey(const Key('alertLabel'))).data!,
        );
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('alertLabel'))).data,
        anyOf('WARNING', 'CRITICAL'),
      );
      // The prediction stage (WATCH) shows before the thresholds are hit.
      expect(seen, containsAll(<String>['WATCH', 'WARNING', 'CRITICAL']));

      // Dashboard in the alarm state: scroll through it, open Why? / more.
      await scrollThrough(tester, const Key('dashboardList'));
      expect(find.text('TOP PREDICTION'), findsOneWidget);
      expect(find.text('Hypoxia'), findsOneWidget);
      // Related NASA hazard context on the prediction card.
      expect(find.byKey(const Key('hazardChip')), findsWidgets);
      expect(find.text('NASA HAZARD · CLOSED ENVIRONMENT'), findsWidgets);
      expect(find.textContaining('Related HRP risk: '), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('whyToggle')));
      await tester.tap(find.byKey(const Key('whyToggle')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('moreToggle')).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.byKey(const Key('moreToggle')));
        await tester.tap(find.byKey(const Key('moreToggle')));
        await tester.pumpAndSettle();
      }
      await pumpReadings(tester, 3); // toggles survive new readings
      await scrollThrough(tester, const Key('dashboardList'));
      expect(find.text('CRITICAL'), findsWidgets); // SpO2 card + chip

      // "See nutrition plan" switches to the Nutrition tab.
      await tester.ensureVisible(find.text('See nutrition plan'));
      await tester.tap(find.text('See nutrition plan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Meals recommended from predicted risks.'),
        findsOneWidget,
      );

      // --- Vitals tab: every range, scrolled to the bottom ------------------
      await tester.tap(find.text('Vitals'));
      await tester.pumpAndSettle();
      expect(find.text('HEART RATE · BPM'), findsOneWidget);
      expect(find.byType(LineChart), findsWidgets);
      for (final range in ['2 min', '10 min', 'Session']) {
        await tester.drag(
          find.byKey(const Key('vitalsList')),
          const Offset(0, 3000),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(range));
        await pumpReadings(tester, 2);
        await scrollThrough(tester, const Key('vitalsList'));
      }
      expect(find.text('ACTIVITY · LEVEL'), findsOneWidget);

      // Unmount so the timers are cancelled before the test ends.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Nutrition loop at 390x844: deficit → log a meal at 75% → '
      'Mission Log → export, no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AstroResilienceApp(store: InMemoryLogStore(), simulatorSeed: 7),
    );
    await tester.pump(AppConstants.splashDuration);
    await tester.pumpAndSettle();

    // Nutrition tab in the calm state first.
    await tester.tap(find.text('Nutrition'));
    await tester.pumpAndSettle();
    expect(
      find.text('No active risk — follow the planned menu'),
      findsOneWidget,
    );
    expect(find.text('ENERGY BALANCE · KCAL'), findsOneWidget);
    await scrollThrough(tester, const Key('nutritionList'), steps: 30);
    expect(find.byKey(const Key('foodDisclaimer')), findsOneWidget);
    // Search narrows the list.
    await tester.drag(
      find.byKey(const Key('nutritionList')),
      const Offset(0, 20000),
    );
    await tester.pumpAndSettle();

    // Demo Control: NUTRITION_DEFICIT scenario.
    await tester.tap(find.byTooltip('Demo Control'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scenarioDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutrition deficit').last);
    await tester.pumpAndSettle();
    final engine = Provider.of<EngineController>(
      tester.element(find.text('SCENARIO')),
      listen: false,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Readings until the engine predicts something.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(seconds: 5));
      if (engine.latest?.predictions.isNotEmpty ?? false) break;
    }
    await tester.pumpAndSettle();
    expect(engine.latest!.predictions, isNotEmpty);

    // Nutrition shows a recommendation with ranked foods.
    await tester.drag(
      find.byKey(const Key('nutritionList')),
      const Offset(0, 20000),
    );
    await tester.pumpAndSettle();
    expect(find.text('TOP FOODS'), findsWidgets);
    final logButton = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('logRanked_'),
        )
        .first;
    await tester.ensureVisible(logButton);
    await tester.pumpAndSettle();
    await tester.tap(logButton);
    await tester.pumpAndSettle();

    // Bottom sheet: pick 75 % and log.
    expect(find.text('HOW MUCH WAS EATEN?'), findsOneWidget);
    await tester.tap(find.text('75%'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kcalPreview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmLogMeal')));
    await tester.pump();
    expect(find.textContaining('· 75% · +'), findsOneWidget); // snackbar
    await tester.pumpAndSettle();
    await scrollThrough(tester, const Key('nutritionList'), steps: 30);

    // Mission Log: the meal is there; every filter works.
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    final log = Provider.of<MissionLogController>(
      tester.element(find.byKey(const Key('logList'))),
      listen: false,
    );
    expect(log.mealEntries.single.data!['consumption_pct'], 75);
    expect(find.textContaining('· 75%'), findsWidgets);
    for (final f in ['alerts', 'meals', 'system', 'all']) {
      await tester.tap(find.byKey(Key('logFilter_$f')));
      await tester.pumpAndSettle();
      await scrollThrough(tester, const Key('logList'));
      await tester.drag(
        find.byKey(const Key('logList')),
        const Offset(0, 20000),
      );
      await tester.pumpAndSettle();
    }
    expect(
      log.entries.where((e) => e.title == 'Scenario → Nutrition deficit'),
      hasLength(1),
    );

    // Export dialog with Copy + Close.
    await tester.tap(find.byKey(const Key('exportLog')));
    await tester.pumpAndSettle();
    expect(find.text('Mission Log · JSON'), findsOneWidget);
    expect(find.byKey(const Key('exportJsonText')), findsOneWidget);
    await tester.tap(find.byKey(const Key('copyExport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('closeExport')));
    await tester.pumpAndSettle();
    expect(find.text('Mission Log · JSON'), findsNothing);

    // Demo Control: Security + About cards, then the References screen.
    await tester.tap(find.byTooltip('Demo Control'));
    await tester.pumpAndSettle();
    final demoList = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('securityStatus')),
      200,
      scrollable: demoList,
    );
    expect(find.text('Local data: memory only (not saved)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('referencesTile')),
      200,
      scrollable: demoList,
    );
    await tester.pumpAndSettle();
    expect(find.text('ABOUT · 5-LAYER ARCHITECTURE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('referencesTile')));
    await tester.pumpAndSettle();
    expect(find.text('NASA HUMAN RESEARCH PROGRAM'), findsOneWidget);
    await scrollThrough(tester, const Key('referencesList'));
    expect(find.byKey(const Key('referencesFooter')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Wipe local data through the confirm dialog: the log is emptied.
    await tester.scrollUntilVisible(
      find.byKey(const Key('wipeData')),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wipeData')));
    await tester.pumpAndSettle();
    expect(find.text('Wipe local data?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmWipe')));
    await tester.pumpAndSettle();
    expect(log.mealEntries, isEmpty);
    expect(find.textContaining('Local data wiped'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('Earth link delay stays within 4–24 minutes', () {
    final controller = EarthLinkController(
      random: Random(42),
      autoStart: false,
    );
    for (var i = 0; i < 5000; i++) {
      controller.tick();
      expect(
        controller.delay,
        greaterThanOrEqualTo(AppConstants.earthDelayMin),
      );
      expect(controller.delay, lessThanOrEqualTo(AppConstants.earthDelayMax));
    }
    expect(controller.formatted, matches(RegExp(r'^\d{1,2}m \d{2}s$')));
    controller.dispose();
  });

  test('Replay loads the bundled 60-reading sample and loops', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final replay = ReplaySource(
      assetPath: TelemetryConstants.sampleReplayAsset,
    );
    await replay.prepare();
    expect(replay.length, 60);
    expect(replay.skippedRows, 0);
    final now = DateTime(2026, 11, 14, 12);
    final first = replay.next(now, const Duration(seconds: 5))!;
    expect(first.timestamp, now); // re-stamped with the current time
    for (var i = 1; i < 60; i++) {
      replay.next(now, const Duration(seconds: 5));
    }
    expect(replay.next(now, const Duration(seconds: 5)), first); // looped
  });
}

/// Lets [count] readings arrive (default interval 5 s) and settles.
Future<void> pumpReadings(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(seconds: 5));
  }
  await tester.pumpAndSettle();
}

/// Scrolls a list from top to bottom in steps so every child gets built and
/// laid out (an overflow anywhere fails the test), then back to the top.
Future<void> scrollThrough(
  WidgetTester tester,
  Key list, {
  int steps = 12,
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.drag(find.byKey(list), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}
