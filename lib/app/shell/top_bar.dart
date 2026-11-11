import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../routes.dart';
import '../state/earth_link_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_logo.dart';
import '../widgets/status_chip.dart';

/// Top bar shown on every tab.
///
/// Row 1: logo + "AstroResilience" + Demo Control button.
/// Row 2: "OFFLINE · EDGE MODE" chip + live "EARTH LINK DELAY" chip.
/// The chip row scales down on very narrow screens instead of overflowing.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key});

  static const double _height = 104;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border,
                width: AppSpacing.borderWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm + AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const AppLogo(size: AppSpacing.topBarLogo),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Demo Control',
                    icon: const Icon(Icons.tune),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.demoControl),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // FittedBox(scaleDown) keeps both chips on one line: on very
              // narrow phones they shrink slightly instead of overflowing.
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      icon: Icons.wifi_off,
                      label: 'Offline · Edge mode',
                      color: AppColors.primary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _EarthDelayChip(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Only this small chip rebuilds when the simulated delay changes.
class _EarthDelayChip extends StatelessWidget {
  const _EarthDelayChip();

  @override
  Widget build(BuildContext context) {
    final formatted = context.select<EarthLinkController, String>(
      (c) => c.formatted,
    );
    return StatusChip(
      icon: Icons.satellite_alt,
      label: 'Earth link delay:',
      value: formatted,
      color: AppColors.info,
    );
  }
}
