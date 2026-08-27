import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A centered glass panel - same flat+blur recipe as the floating bottom
/// nav and the Histórico period pills (translucent surface + a thin
/// border), instead of the heavier, always-dark "liquid glass" look this
/// used to have. Theme-aware now, like the rest of the app - light glass in
/// light mode, dark glass in dark mode. The blur itself is applied to the
/// *whole* screen behind the panel (not just clipped to the panel's own
/// bounds) so everything else goes soft-focus while this is open, not just
/// dimmed. Used for the register-entry form and the floating Altura/Meta
/// editors; other sheets keep [showSumaFloatingSheet]'s bottom-anchored
/// look.
Future<T?> showSumaGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 420,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.transparent, // the full-screen blur below does the dimming
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12), blurRadius: 32, offset: const Offset(0, 16))],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(24), child: builder(ctx)),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      // A soft, "ofuscado" blur (not a hard frosted wall) over the rest of
      // the screen - just enough to pull focus onto the panel.
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14 * anim.value, sigmaY: 14 * anim.value),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.22 * anim.value),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
