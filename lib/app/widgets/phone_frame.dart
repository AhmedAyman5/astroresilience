import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Keeps the whole app phone-shaped on wide (desktop web) windows: the app
/// is centered with a max width and thin side borders. On a phone the frame
/// is invisible because the screen is narrower than the max width.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > AppSpacing.maxContentWidth;
          if (!wide) return child;
          return Center(
            child: Container(
              width: AppSpacing.maxContentWidth,
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(
                    color: AppColors.border,
                    width: AppSpacing.borderWidth,
                  ),
                ),
              ),
              // Tell child widgets the real (narrow) width they get.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(
                    AppSpacing.maxContentWidth,
                    constraints.maxHeight,
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
