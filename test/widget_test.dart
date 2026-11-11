import 'dart:math';

import 'package:astroresilience/app/app.dart';
import 'package:astroresilience/app/state/earth_link_controller.dart';
import 'package:astroresilience/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('OFFLINE · EDGE MODE'), findsOneWidget);
    expect(find.text('EARTH LINK DELAY:'), findsOneWidget);
    for (final tab in ['Mission', 'Vitals', 'Nutrition', 'Log']) {
      expect(find.text(tab), findsOneWidget);
    }

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
}
