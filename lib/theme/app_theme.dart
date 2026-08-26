import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for Suma. The goal is a soft, rounded, "modern
/// iOS/Notion" feel - big rounded cards with a faint shadow instead of
/// Material elevation, pill-shaped controls, a flat ripple instead of
/// Android's sparkle effect - built on top of the brand palette from the
/// Suma logo rather than Material You's per-device dynamic color.
class AppColors {
  AppColors._();

  // Brand palette (from the Suma logo).
  static const Color cyan = Color(0xFF24C5E5);
  static const Color deepBlue = Color(0xFF035EB3);
  static const Color mint = Color(0xFF93E5AB);
  static const Color deepTeal = Color(0xFF042A2B);
  static const Color green = Color(0xFF6BA368);

  static const Color brand = cyan;

  static const Color fatAccent = mint;
  static const Color hydrationAccent = deepBlue;
  static const Color positive = green;
  static const Color negative = Color(0xFFE5484D);
  static const Color goalAccent = green;

  // Grouped background tones - light stays close to iOS system-gray. Dark
  // is true black with plain gray surfaces (no brand tint) so the palette
  // reads purely through accents, not through the background itself.
  static const Color lightBackground = Color(0xFFF1F7F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceAlt = Color(0xFF1E1E1E);

  /// Distinct colors cycled through when plotting/labelling more than one
  /// person at once (Histórico's family comparison chart and picker chips).
  static const List<Color> series = [cyan, deepBlue, green, mint, negative];

  static Color seriesColor(int index) => series[index % series.length];
}

class AppTheme {
  AppTheme._();

  static const double cardRadius = 22;
  static const double controlRadius = 16;
  static const double pillRadius = 100;

  // Built once and reused - AppState.notifyListeners() fires often (every
  // entry edit, family refresh, optimistic pref update), and MaterialApp
  // re-reads `theme`/`darkTheme` on every rebuild it's part of. Rebuilding a
  // full ColorScheme.fromSeed + text theme from scratch each time was a real,
  // measurable jank source on Windows - these are static and never change at
  // runtime, so compute them exactly once.
  static final ThemeData _light = _build(Brightness.light);
  static final ThemeData _dark = _build(Brightness.dark);

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: brightness).copyWith(
      primary: AppColors.brand,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? Colors.white : AppColors.deepTeal,
      error: AppColors.negative,
    );
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      // A flat ripple instead of Material You's sparkle effect - reads
      // closer to an iOS/Notion tap than stock Android 12+.
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      // Inter instead of the platform default (Roboto/Segoe) - a rounder,
      // more "app-native" feel closer to the iOS/Notion reference look.
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFEFF6F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      // A solid, fully-saturated brand-cyan fill on the selected segment read
      // as too heavy/loud for a control used this often (unit, theme,
      // goal type) - a soft tinted fill with brand-colored text/icon instead
      // is the same information at a calmer volume, closer to how iOS treats
      // segmented controls.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.16),
          selectedForegroundColor: scheme.primary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFEFF6F7),
        selectedColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      // Stock Material 3 popup menus (rounded-but-square, hard elevation
      // shadow) read very "Android settings screen" - round them further
      // and flatten the shadow to match the rest of the app's cards.
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 14.5),
      ),
      // Stock M3 snackbars float as a pill with a bright, dynamic-color fill
      // - a plain dark/light bar with a fixed brand-neutral tone reads
      // calmer and more native-feeling.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.deepTeal,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        actionTextColor: AppColors.cyan,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.positive : scheme.outlineVariant,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, circularTrackColor: scheme.outlineVariant.withValues(alpha: 0.4)),
    );
  }
}
