import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/app_logo.dart';
import '../../core/constants/app_constants.dart';

/// Splash: logo + name + "Initializing edge engine…" for ~1.5 seconds,
/// then replaces itself with the main app shell.
///
/// A single gold shimmer sweeps across the logo once (no loop), like light
/// moving over a golden pharaonic mask.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;

  // Plays forward once and stops (never repeats), so tests can settle.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: AppMotion.splashShimmer,
  )..forward();

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppConstants.splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShimmerLogo(animation: _shimmer),
              const SizedBox(height: AppSpacing.lg),
              Text(AppConstants.appName, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'EDGE HEALTH SYSTEM',
                style: AppTypography.consoleLabel,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(minHeight: 2),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Initializing edge engine…',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The splash logo with a gold highlight band that sweeps from left to right.
class _ShimmerLogo extends StatelessWidget {
  const _ShimmerLogo({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // The band starts off the left edge (t = 0) and ends off the right
        // edge (t = 1). srcATop paints it only on top of the logo pixels.
        final t = AppMotion.splashShimmerCurve.transform(animation.value);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-3 + 4 * t, -0.4),
            end: Alignment(-1 + 4 * t, 0.4),
            colors: [
              Colors.transparent,
              AppColors.primary.withValues(alpha: AppMotion.splashShimmerAlpha),
              Colors.transparent,
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
      child: const AppLogo(size: AppSpacing.splashLogo),
    );
  }
}
