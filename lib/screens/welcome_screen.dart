import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../widgets/auth_field_style.dart';
import '../widgets/auth_wave_panel.dart';
import '../widgets/suma_mark.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// First screen shown when nobody is signed in: a single card with a
/// Login/Cadastro tab switcher at the top - no separate "choose" step, both
/// forms are one tap away from each other. Desktop-width windows add the
/// abstract wave-art panel beside the card; phone-width windows show just
/// the card, full-bleed.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tab = 0; // 0 = login, 1 = signup

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktop(context);
    final card = _AuthCardContent(tab: _tab, onTabChanged: (t) => setState(() => _tab = t));

    if (desktop) {
      return Scaffold(
        backgroundColor: authPageColor(context),
        body: Row(
          children: [
            const Expanded(flex: 6, child: AuthWavePanel()),
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: card),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: authPageColor(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: card),
          ),
        ),
      ),
    );
  }
}

class _AuthCardContent extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTabChanged;
  const _AuthCardContent({required this.tab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              const SumaMark(size: 44),
              const SizedBox(height: 10),
              Text('Suma', style: TextStyle(color: authTextColor(context), fontSize: 26, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 26),
        AuthTabSwitcher(index: tab, onChanged: onTabChanged),
        const SizedBox(height: 22),
        if (tab == 0)
          LoginForm(onSwitchToSignup: () => onTabChanged(1))
        else
          SignupForm(onSwitchToLogin: () => onTabChanged(0)),
      ],
    );
  }
}
