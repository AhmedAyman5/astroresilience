import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The AstroResilience logo (assets/images/logo.png).
///
/// If the image is missing or fails to load, we fall back to a plain
/// International Orange circle so the app never shows a broken image.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size});

  static const String assetPath = 'assets/images/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    // The logo has a dark square background, so we clip it to rounded corners.
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Decode at display size (x3 for high-DPI screens) to save memory:
        // the source image is ~1250px wide.
        cacheWidth: (size * 3).round(),
        semanticLabel: 'AstroResilience logo',
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
