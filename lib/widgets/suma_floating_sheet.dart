import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Shows [builder]'s content as a floating, rounded-on-every-corner card
/// with a light frosted-glass blur behind it, instead of a flat edge-to-edge
/// Material bottom sheet. Used for the entry form and the date picker - the
/// two places asked to read as a detached "floating menu" rather than a
/// sheet glued to the screen edge.
///
/// Bottom-anchored (with margin, so it still floats) on phone-width windows
/// for thumb reach; centered like a dialog on desktop-width ones.
Future<T?> showSumaFloatingSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 460,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secAnim) {
      final desktop = Responsive.isDesktop(ctx);
      return SafeArea(
        child: Align(
          alignment: desktop ? Alignment.center : Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(desktop ? 24 : 12, 24, desktop ? 24 : 12, desktop ? 24 : 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(ctx).size.height * 0.86),
              child: Material(
                color: scheme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
