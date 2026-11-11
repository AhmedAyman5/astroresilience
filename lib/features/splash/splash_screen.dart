import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/app_logo.dart';
import '../../core/constants/app_constants.dart';

/// Splash: logo + name + "Initializing edge engine…" for ~1.5 seconds,
/// then replaces itself with the main app shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

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
              const AppLogo(size: AppSpacing.splashLogo),
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
