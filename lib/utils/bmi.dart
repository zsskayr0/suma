import 'package:flutter/material.dart';

/// Simple IMC/BMI helpers shared by the dashboard (real-time, from the latest
/// entry) and the onboarding flow (live preview while typing).
class Bmi {
  /// Returns null when either input is missing/invalid.
  static double? calculate({required double? weightKg, required double? heightCm}) {
    if (weightKg == null || heightCm == null) return null;
    if (weightKg <= 0 || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static String category(double bmi) {
    if (bmi < 18.5) return 'Abaixo do peso';
    if (bmi < 25) return 'Peso normal';
    if (bmi < 30) return 'Sobrepeso';
    if (bmi < 35) return 'Obesidade I';
    if (bmi < 40) return 'Obesidade II';
    return 'Obesidade III';
  }

  /// A color that reads consistently in light and dark (mid-tone, never pure
  /// white/black) for the BMI pill and progress indicators.
  static Color color(double bmi) {
    if (bmi < 18.5) return const Color(0xFF0A84FF); // abaixo do peso - azul
    if (bmi < 25) return const Color(0xFF30D158); // normal - verde
    if (bmi < 30) return const Color(0xFFFF9F0A); // sobrepeso - laranja
    return const Color(0xFFFF453A); // obesidade - vermelho
  }
}
