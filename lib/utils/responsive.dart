import 'package:flutter/material.dart';

/// Breakpoints used across the app so the desktop build (Windows) gets a
/// wider, denser layout instead of a stretched-out phone screen, while phone
/// widths keep the compact single-column layout.
class Responsive {
  Responsive._();

  static const double tablet = 700;
  static const double desktop = 980;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) => widthOf(context) >= tablet;

  static bool isDesktop(BuildContext context) => widthOf(context) >= desktop;

  /// How many columns a stat grid should use at the current width.
  static int statColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktop) return 4;
    if (w >= tablet) return 3;
    return 2;
  }

  /// Caps content width on very wide desktop windows so cards/text don't
  /// stretch edge-to-edge, while still using noticeably more horizontal
  /// space than the phone layout.
  static double maxContentWidth(BuildContext context) => isDesktop(context) ? 1120 : (isTablet(context) ? 760 : double.infinity);
}
