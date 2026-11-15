import 'package:flutter/foundation.dart';

/// The 4 bottom-navigation tabs, in order.
enum AppTab { mission, vitals, nutrition, log }

/// Which tab is open. Shared state so any screen can switch tabs
/// (e.g. the "See nutrition plan" button on the dashboard).
class ShellNavigation extends ChangeNotifier {
  AppTab _tab = AppTab.mission;

  AppTab get tab => _tab;

  void open(AppTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
