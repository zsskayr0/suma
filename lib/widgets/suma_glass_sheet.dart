import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A centered glass panel - same flat+blur recipe as the floating bottom
/// nav and the Histórico period pills (translucent surface + backdrop blur
/// + a thin border), instead of the heavier, always-dark "liquid glass"
/// look this used to have. Theme-aware now, like the rest of the app -
/// light glass in light mode, dark glass in dark mode. Used for the
/// register-entry form; other sheets keep [showSumaFloatingSheet]'s
/// bottom-anchored look.
Future<T?> showSumaGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 420,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim, secAnim) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(ctx).size.height * 0.86),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12), blurRadius: 32, offset: const Offset(0, 16))],
                    ),
                    child: builder(ctx),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
