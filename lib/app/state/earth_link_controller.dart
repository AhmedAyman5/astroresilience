import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// Simulates the Earth ↔ Mars communication delay shown in the top bar.
///
/// The delay does a slow, bounded random walk between 4 and 24 minutes.
/// It has "momentum" (a drift direction that only changes occasionally) so
/// the value moves smoothly instead of jittering up and down.
class EarthLinkController extends ChangeNotifier {
  EarthLinkController({Random? random, bool autoStart = true})
    : _random = random ?? Random() {
    if (autoStart) start();
  }

  final Random _random;
  Timer? _timer;

  Duration _delay = AppConstants.earthDelayStart;

  /// +1 = delay growing, -1 = delay shrinking.
  int _direction = 1;

  /// Current simulated one-way delay.
  Duration get delay => _delay;

  /// Formatted like "12m 40s" for the top-bar chip.
  String get formatted {
    final minutes = _delay.inMinutes;
    final seconds = _delay.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConstants.earthDelayTick, (_) => tick());
  }

  /// One step of the random walk. Public so tests can drive it directly.
  @visibleForTesting
  void tick() {
    // Occasionally (10% of ticks) flip the drift direction.
    if (_random.nextDouble() < 0.1) _direction = -_direction;

    final step = 1 + _random.nextInt(AppConstants.earthDelayMaxStepSeconds);
    var next = _delay.inSeconds + _direction * step;

    // Bounce off the 4–24 minute limits.
    final minS = AppConstants.earthDelayMin.inSeconds;
    final maxS = AppConstants.earthDelayMax.inSeconds;
    if (next <= minS || next >= maxS) {
      _direction = -_direction;
      next = next.clamp(minS, maxS);
    }

    _delay = Duration(seconds: next);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
