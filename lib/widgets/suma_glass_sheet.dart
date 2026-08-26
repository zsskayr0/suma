import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A centered "liquid glass" panel: always a dark frosted-glass surface
/// regardless of the app's own light/dark setting - like a Figma/macOS
/// precision-tool palette floating over the document, not a themed sheet.
/// Sits over a soft gradient scrim (instead of a flat dimmed barrier) so the
/// blur behind it actually has something to catch. Used specifically for
/// the register-entry form; other sheets keep [showSumaFloatingSheet]'s
/// theme-adaptive look.
Future<T?> showSumaGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 420,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.transparent, // the gradient scrim below replaces it
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim, secAnim) {
      return Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.deepTeal.withValues(alpha: 0.68),
                    Colors.black.withValues(alpha: 0.58),
                    AppColors.deepBlue.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(ctx).size.height * 0.86),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 36, offset: const Offset(0, 18))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: builder(ctx),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22 * anim.value, sigmaY: 22 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
