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
                // Without a Material ancestor, Text widgets that don't set
                // their own fontSize fall back to Flutter's bare
                // WidgetsApp default instead of the app's actual type
                // scale - which is a lot bigger, not smaller, and is
                // exactly what made "Masculino" render enormous here.
                // MaterialType.transparency paints nothing on its own (the
                // DecoratedBox above already handles the panel's
                // background) but properly scopes DefaultTextStyle/
                // IconTheme/ink for everything inside.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    type: MaterialType.transparency,
                    textStyle: Theme.of(ctx).textTheme.bodyMedium,
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
      // The full-screen blur used to be a single ColoredBox wrapping the
      // panel too - ColoredBox always counts as hit-testable (it paints),
      // so it silently absorbed every tap anywhere on screen before it
      // could reach the barrier underneath, breaking tap-outside-to-dismiss
      // everywhere this sheet is used. Splitting it into its own Stack
      // layer - with an explicit dismiss tap handler - and the panel as a
      // separate layer on top fixes that: taps that land on the panel are
      // absorbed by *it* (Material paints, so it's hit-testable) before
      // reaching this layer, but taps anywhere else now actually dismiss.
      return Stack(
        children: [
          // RepaintBoundary here is load-bearing, not defensive: anything
          // animating in the panel (the theme picker's sun/moon icon, the
          // notification sheet's clock hands, ...) sits in a *sibling*
          // layer, but without isolating each side Flutter still re-walks
          // this whole Stack - including re-executing the blur - on every
          // one of that animation's frames, even though the blur's own
          // inputs haven't changed. BackdropFilter is already one of the
          // most expensive things Flutter can paint; redoing it 60x/sec
          // because of an unrelated icon animating nearby is what was
          // actually making the theme picker stutter, not the theme
          // switch itself. Isolating both sides lets Flutter cache the
          // blur's layer across frames where it hasn't changed.
          RepaintBoundary(
            child: Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14 * anim.value, sigmaY: 14 * anim.value),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.22 * anim.value)),
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}
