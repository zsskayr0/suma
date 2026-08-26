import 'package:flutter/material.dart';

/// The Suma logo mark (the "S" swoosh), used on branding moments - Entrar/
/// Criar conta, the desktop sidebar, and the app icon source. The asset is a
/// transparent PNG, so this just draws it at the requested size - no clipping
/// or background needed, it sits directly on whatever surface is behind it.
class SumaMark extends StatelessWidget {
  final double size;

  const SumaMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/branding/suma_mark.png', width: size, height: size, fit: BoxFit.contain);
  }
}
