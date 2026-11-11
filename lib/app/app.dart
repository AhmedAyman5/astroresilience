import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
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
        // Phase 2+: telemetry, engine, nutrition and security providers.
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
