import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../layers/engine/engine_controller.dart';
import '../layers/nutrition/energy_balance_service.dart';
import '../layers/telemetry/telemetry_controller.dart';
import 'routes.dart';
import 'state/earth_link_controller.dart';
import 'theme/app_theme.dart';

/// Root widget: registers app-wide state (providers) and the theme.
class AstroResilienceApp extends StatelessWidget {
  const AstroResilienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Simulated Earth ↔ Mars delay shown in the top bar.
        ChangeNotifierProvider(create: (_) => EarthLinkController()),
        // Layer 1: telemetry. lazy: false = starts with the app, so readings
        // are already flowing while the splash screen is shown.
        ChangeNotifierProvider(
          create: (_) => TelemetryController(),
          lazy: false,
        ),
        // Layer 3 input: energy balance (intake is logged in Phase 4).
        ChangeNotifierProvider(create: (_) => EnergyBalanceService()),
        // Layer 2: edge engine, fed by telemetry + energy balance.
        ChangeNotifierProvider(
          create: (context) => EngineController(
            telemetry: context.read<TelemetryController>(),
            energy: context.read<EnergyBalanceService>(),
          ),
          lazy: false,
        ),
        // Phase 4+: nutrition recommender and security providers.
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.table,
      ),
    );
  }
}
