import 'dart:math';

import 'package:astroresilience/app/app.dart';
import 'package:astroresilience/app/state/earth_link_controller.dart';
import 'package:astroresilience/core/constants/app_constants.dart';
import 'package:astroresilience/core/constants/telemetry_constants.dart';
import 'package:astroresilience/core/models/scenario.dart';
import 'package:astroresilience/layers/telemetry/replay_source.dart';
import 'package:astroresilience/layers/telemetry/telemetry_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Splash shows, then the shell with 4 tabs and top-bar chips', (
    tester,
  ) async {
    // Phone size from the Definition of Done: 390 x 844.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AstroResilienceApp());
    expect(find.text('Initializing edge engine…'), findsOneWidget);

    // Wait for the splash timer and the route transition.
    await tester.pump(AppConstants.splashDuration);
    await tester.pumpAndSettle();

    expect(find.text('Mission Dashboard'), findsOneWidget);
    // Phase 2 debug view: the engine has processed the first reading.
    // (The engine card is below the fold, hence skipOffstage: false.)
    expect(find.text('/ 100 RISK SCORE', skipOffstage: false), findsOneWidget);
    expect(find.text('OFFLINE · EDGE MODE'), findsOneWidget);
    expect(find.text('EARTH LINK DELAY:'), findsOneWidget);
    for (final tab in ['Mission', 'Vitals', 'Nutrition', 'Log']) {
      expect(find.text(tab), findsOneWidget);
    }

    // Switch scenario from the debug dropdown and let 3 minutes pass.
    await tester.tap(find.text('Nominal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hypoxia event').last);
    await tester.pumpAndSettle();
    final telemetry = Provider.of<TelemetryController>(
      tester.element(find.text('Mission Dashboard')),
      listen: false,
    );
    expect(telemetry.scenario, Scenario.hypoxiaEvent);
    for (var i = 0; i < 36; i++) {
      await tester.pump(const Duration(seconds: 5));
    }

    // Scroll to the bottom of the debug view: no overflow at 390 px.
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Hypoxia'), findsOneWidget);
    expect(find.text('CRITICAL'), findsWidgets);
    expect(find.text('WHY?'), findsWidgets);

    // Switch to the Nutrition tab.
    await tester.tap(find.text('Nutrition'));
    await tester.pumpAndSettle();
    expect(
      find.text('Meals recommended from predicted risks.'),
      findsOneWidget,
    );

    // Open Demo Control from the top bar.
    await tester.tap(find.byTooltip('Demo Control'));
    await tester.pumpAndSettle();
    expect(find.text('Drive the live demo for the judges.'), findsOneWidget);

    // Unmount so the Earth-link timer is cancelled before the test ends.
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
