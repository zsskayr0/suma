import 'package:flutter/material.dart';

/// The desktop login card's left panel - the abstract wave/silk artwork
/// provided for the design, filling the panel edge to edge.
class AuthWavePanel extends StatelessWidget {
  const AuthWavePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/auth_wave.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
    );
  }
}
