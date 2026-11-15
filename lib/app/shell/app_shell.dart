import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/log/mission_log_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/vitals/vitals_screen.dart';
import '../state/shell_navigation.dart';
import 'top_bar.dart';

/// Main app frame: top bar + 4 tabs + bottom navigation.
///
/// Tabs are kept alive in an [IndexedStack] so switching tabs does not reset
/// charts or scroll positions. The open tab lives in [ShellNavigation], so
/// other screens can switch tabs too.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<Widget> _tabs = [
    DashboardScreen(),
    VitalsScreen(),
    NutritionScreen(),
    MissionLogScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNavigation>();
    final index = nav.tab.index;
    return Scaffold(
      appBar: const TopBar(),
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        // 1px top border instead of a shadow (design system rule).
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => nav.open(AppTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Mission',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart),
              label: 'Vitals',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Nutrition',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Log',
            ),
          ],
        ),
      ),
    );
  }
}
