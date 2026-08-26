import 'package:flutter/material.dart';

import '../widgets/suma_mark.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

enum _AuthMode { welcome, login, signup }

/// First screen shown when nobody is signed in: choose between signing into
/// an existing account or creating a new one. Account creation and family
/// linking ("criar minha rede" / "entrar com código") are two separate
/// decisions - this screen only handles the former; the latter is offered
/// during onboarding, right after a fresh sign-up.
///
/// Login/signup are swapped in as plain widgets (no Navigator push) so that
/// when [AppState] moves past `needsAuth`, `_RootRouter` can just swap this
/// whole screen out - no pushed route left stranded on top of it.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  _AuthMode _mode = _AuthMode.welcome;

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _AuthMode.login:
        return LoginScreen(onBack: () => setState(() => _mode = _AuthMode.welcome));
      case _AuthMode.signup:
        return SignupScreen(onBack: () => setState(() => _mode = _AuthMode.welcome));
      case _AuthMode.welcome:
        return _WelcomeBody(
          onLogin: () => setState(() => _mode = _AuthMode.login),
          onSignup: () => setState(() => _mode = _AuthMode.signup),
        );
    }
  }
}

class _WelcomeBody extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  const _WelcomeBody({required this.onLogin, required this.onSignup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SumaMark(size: 84)),
                const SizedBox(height: 16),
                Text('Suma', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                Text('Monitoramento de peso para você e sua família', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 40),
                FilledButton(onPressed: onLogin, child: const Text('Entrar')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onSignup, child: const Text('Criar conta')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
