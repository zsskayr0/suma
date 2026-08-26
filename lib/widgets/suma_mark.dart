import 'package:flutter/material.dart';

/// The Suma logo mark (rounded-square badge), used on branding moments -
/// Entrar/Criar conta, and the desktop sidebar. The source PNG already has
/// a white square background, so this only rounds its corners; it's not
/// tinted per-theme (the mark itself is the brand, it shouldn't change).
class SumaMark extends StatelessWidget {
  final double size;
  final BorderRadius? borderRadius;

  const SumaMark({super.key, this.size = 56, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * 0.28),
      child: Image.asset('assets/branding/suma_mark.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}
