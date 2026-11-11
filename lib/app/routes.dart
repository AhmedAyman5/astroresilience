import 'package:flutter/material.dart';

import '../features/demo_control/demo_control_screen.dart';
import '../features/splash/splash_screen.dart';
import 'shell/app_shell.dart';

/// Named routes of the app. Tabs live inside [AppShell]; only full-screen
/// pages get a route here.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String shell = '/mission';
  static const String demoControl = '/demo-control';

  static Map<String, WidgetBuilder> get table => {
    splash: (_) => const SplashScreen(),
    shell: (_) => const AppShell(),
    demoControl: (_) => const DemoControlScreen(),
  };
}
