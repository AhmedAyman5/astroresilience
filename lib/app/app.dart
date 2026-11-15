import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../layers/engine/engine_controller.dart';
import '../layers/log/mission_log_controller.dart';
import '../layers/nutrition/energy_balance_service.dart';
import '../layers/nutrition/nutrition_controller.dart';
import '../layers/security/log_store.dart';
import '../layers/security/security_service.dart';
import '../layers/telemetry/simulated_source.dart';
import '../layers/telemetry/telemetry_controller.dart';
import 'routes.dart';
import 'state/earth_link_controller.dart';
import 'state/shell_navigation.dart';
import 'theme/app_theme.dart';
import 'widgets/phone_frame.dart';

/// Root widget: registers app-wide state (providers) and the theme.
class AstroResilienceApp extends StatelessWidget {
  const AstroResilienceApp({
    super.key,
    this.store,
    this.storeError,
    this.simulatorSeed,
  });

  /// Where the Mission Log (and meal history) is kept. main.dart passes the
  /// encrypted store; tests pass an InMemoryLogStore (no plugins needed).
  /// null = memory only.
  final LogStore? store;

  /// Why the encrypted store could not be opened (shown in Demo Control).
  final String? storeError;

  /// Fixed random seed for the simulator (tests only, so a run is
  /// repeatable). null = a new random walk every launch.
  final int? simulatorSeed;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Simulated Earth ↔ Mars delay shown in the top bar.
        ChangeNotifierProvider(create: (_) => EarthLinkController()),
        // Which bottom tab is open (lets the dashboard jump to Nutrition).
        ChangeNotifierProvider(create: (_) => ShellNavigation()),
        // Layer 1: telemetry. lazy: false = starts with the app, so readings
        // are already flowing while the splash screen is shown.
        ChangeNotifierProvider(
          create: (_) => TelemetryController(
            simulated: SimulatedSource(
              random: simulatorSeed == null ? null : Random(simulatorSeed),
            ),
          ),
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
        // Layer 5 storage behind an interface (encrypted or memory only).
        Provider<LogStore>(create: (_) => store ?? InMemoryLogStore()),
        // Mission Log: records status changes, predictions, meals and
        // simulator events. lazy: false so it records from the first reading.
        ChangeNotifierProvider(
          create: (context) => MissionLogController(
            store: context.read<LogStore>(),
            engine: context.read<EngineController>(),
            telemetry: context.read<TelemetryController>(),
          ),
          lazy: false,
        ),
        // Layer 5: encryption status + "Wipe local data".
        ChangeNotifierProvider(
          create: (context) => SecurityService(
            store: context.read<LogStore>(),
            log: context.read<MissionLogController>(),
            openError: storeError,
          ),
        ),
        // Layer 3: Predictive Nutrition Loop (ranked foods + meal logging).
        ChangeNotifierProvider(
          create: (context) => NutritionController(
            engine: context.read<EngineController>(),
            log: context.read<MissionLogController>(),
            energy: context.read<EnergyBalanceService>(),
          ),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.table,
        // Phone-shaped, centered layout on wide desktop windows.
        builder: (context, child) => PhoneFrame(child: child!),
      ),
    );
  }
}
