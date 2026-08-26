import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_theme.dart';

/// The dark, hairline-bordered field style shared by the login and signup
/// forms - matches the reference design regardless of the device's own
/// light/dark preference (there's no user to have a preference yet).
InputDecoration authFieldDecoration({required String label, required HeroIcons icon, Widget? suffixIcon}) {
  OutlineInputBorder border(Color color, double width) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: width));
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13.5),
    floatingLabelStyle: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w600, fontSize: 13),
    prefixIcon: HeroIcon(icon, style: HeroIconStyle.outline, size: 19, color: Colors.white54),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.045),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: border(Colors.white.withValues(alpha: 0.14), 1),
    border: border(Colors.white.withValues(alpha: 0.14), 1),
    focusedBorder: border(AppColors.cyan.withValues(alpha: 0.85), 1.3),
    errorBorder: border(AppColors.negative.withValues(alpha: 0.7), 1),
    focusedErrorBorder: border(AppColors.negative, 1.3),
    errorStyle: const TextStyle(color: AppColors.negative, fontSize: 11.5),
  );
}

const authValueStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15);
