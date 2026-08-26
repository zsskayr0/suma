import 'dart:ui';

import 'package:flutter/material.dart';

/// Shows [builder]'s content as a small floating panel anchored to whatever
/// widget [anchorKey] is attached to - growing from the button that opened
/// it (below by default, flipped above if there isn't room) instead of
/// taking over the middle of the screen. Matches the "Filters" reference:
/// a compact rounded dark card right under the trigger, dismissed by
/// tapping anywhere outside it.
Future<T?> showSumaPopover<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required GlobalKey anchorKey,
  double width = 380,
}) {
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
  final Rect anchorRect;
  if (anchorBox != null && anchorBox.attached) {
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    anchorRect = topLeft & anchorBox.size;
  } else {
    // No anchor to measure (shouldn't normally happen) - fall back to a
    // sensible top-right corner instead of crashing.
    anchorRect = Rect.fromLTWH(overlayBox.size.width - 24, 24, 0, 0);
  }
  final scheme = Theme.of(context).colorScheme;

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, anim, secAnim) {
      final screen = MediaQuery.of(ctx).size;
      const gap = 10.0;
      const margin = 14.0;

      final spaceBelow = screen.height - anchorRect.bottom - gap - margin;
      final spaceAbove = anchorRect.top - gap - margin;
      final openBelow = spaceBelow >= 220 || spaceBelow >= spaceAbove;
      final panelMaxHeight = (openBelow ? spaceBelow : spaceAbove).clamp(180.0, screen.height * 0.78);

      var left = anchorRect.right - width;
      left = left.clamp(margin, screen.width - width - margin);

      return Stack(
        children: [
          Positioned(
            left: left,
            top: openBelow ? anchorRect.bottom + gap : null,
            bottom: openBelow ? null : screen.height - anchorRect.top + gap,
            width: width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: panelMaxHeight),
              child: Material(
                color: scheme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.4),
                child: builder(ctx),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4 * anim.value, sigmaY: 4 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        ),
      );
    },
  );
}
