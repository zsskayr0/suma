import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'suma_mark.dart';

enum AuthPanelMode { welcome, login, signup }

/// The moody blue gradient "hero" panel from the reference design - on
/// desktop it sits beside the login/signup form; on mobile it's shown by
/// itself as the welcome screen, with the entry buttons in place of the
/// step preview. Always dark, independent of the device's own theme
/// (there's no signed-in profile yet to carry a light/dark preference).
class AuthGradientPanel extends StatelessWidget {
  final AuthPanelMode mode;
  final VoidCallback? onLoginTap;
  final VoidCallback? onSignupTap;

  const AuthGradientPanel({super.key, required this.mode, this.onLoginTap, this.onSignupTap});

  @override
  Widget build(BuildContext context) {
    final isSignup = mode == AuthPanelMode.signup;
    final isWelcome = mode == AuthPanelMode.welcome;

    // True black, not a wash of blue - the gradient is a single muted glow
    // tucked in one corner (like a distant sun), fading out quickly instead
    // of covering the whole panel.
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -160,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withValues(alpha: 0.55),
                    AppColors.deepBlue.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SumaMark(size: 30),
                  const Spacer(),
                  Text(
                    isWelcome
                        ? 'Monitore seu peso\ncom quem importa'
                        : (isSignup ? 'Comece agora\ncom o Suma' : 'Que bom te ver\nde novo'),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isWelcome
                        ? 'Acompanhe sua evolução e a da sua família em um só lugar.'
                        : (isSignup ? 'Complete estes passos para configurar sua conta.' : 'Entre com sua conta para continuar de onde parou.'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  if (isWelcome)
                    _WelcomeButtons(onLoginTap: onLoginTap, onSignupTap: onSignupTap)
                  else if (isSignup)
                    const _StepRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeButtons extends StatelessWidget {
  final VoidCallback? onLoginTap;
  final VoidCallback? onSignupTap;
  const _WelcomeButtons({this.onLoginTap, this.onSignupTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onSignupTap,
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
          child: const Text('Criar conta'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onLoginTap,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), minimumSize: const Size.fromHeight(50)),
          child: const Text('Entrar'),
        ),
      ],
    );
  }
}

/// The account-setup preview from the reference (its 3-step tracker) -
/// mapped to Suma's actual post-signup flow: identity, then profile, then
/// joining/creating a family network.
class _StepRow extends StatelessWidget {
  const _StepRow();

  static const _steps = ['Criar sua conta', 'Configurar seu perfil', 'Entrar na rede da família'];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i != 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: i == 0 ? Colors.white : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: i == 0 ? Colors.black : Colors.white.withValues(alpha: 0.25),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  Text(_steps[i], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: i == 0 ? Colors.black : Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
