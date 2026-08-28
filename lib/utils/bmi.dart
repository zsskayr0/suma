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

  /// The "healthy" weight range (BMI 18.5-24.9) for someone of [heightCm] -
  /// shown as a reference next to the goal weight editor. Null without a
  /// height on file.
  static (double min, double max)? idealWeightRangeKg(double? heightCm) {
    if (heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return (18.5 * heightM * heightM, 24.9 * heightM * heightM);
  }
}

/// One WHO BMI band - the granular 8-tier breakdown (vs. [Bmi.category]'s
/// coarse 6-tier one used everywhere else) that backs the gauge and the
/// full category list on the IMC detail screen. [max] is null for the
/// open-ended top band (Obesidade grave).
class BmiBand {
  final String label;
  final double min;
  final double? max;
  final Color color;
  const BmiBand({required this.label, required this.min, required this.max, required this.color});

  bool contains(double bmi) => bmi >= min && (max == null || bmi < max!);
}

/// Ordered low to high - [gaugeMin]/[gaugeMax] below are this list's actual
/// bounds, used to scale the gauge arc.
const bmiBands = <BmiBand>[
  BmiBand(label: 'Baixo peso grave', min: 0, max: 16.0, color: Color(0xFF0A84FF)),
  BmiBand(label: 'Baixo peso moderado', min: 16.0, max: 17.0, color: Color(0xFF3AA0FF)),
  BmiBand(label: 'Baixo peso leve', min: 17.0, max: 18.5, color: Color(0xFF7FC1FF)),
  BmiBand(label: 'Peso normal', min: 18.5, max: 25.0, color: Color(0xFF30D158)),
  BmiBand(label: 'Sobrepeso', min: 25.0, max: 30.0, color: Color(0xFFFF9F0A)),
  BmiBand(label: 'Obesidade grau I', min: 30.0, max: 35.0, color: Color(0xFFFF6A3A)),
  BmiBand(label: 'Obesidade grau II', min: 35.0, max: 40.0, color: Color(0xFFFF453A)),
  BmiBand(label: 'Obesidade grau III', min: 40.0, max: null, color: Color(0xFFD70015)),
];

/// The band [bmi] falls into - the lowest or highest band when out of the
/// table's normal bounds entirely (a BMI of 5 or 60 is real, if extreme).
BmiBand bmiBandFor(double bmi) => bmiBands.firstWhere((b) => b.contains(bmi), orElse: () => bmi < bmiBands.first.min ? bmiBands.first : bmiBands.last);
