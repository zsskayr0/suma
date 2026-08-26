import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../widgets/auth_gradient_panel.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// First screen shown when nobody is signed in.
///
/// Desktop-width windows show the full reference layout: the gradient hero
/// panel and the login/signup form side by side, permanently - only the
/// form panel's content swaps between the two, so the hero panel never
/// remounts. Phone-width windows only have room for one at a time, so they
/// show just the hero panel (with the entry buttons in place of the step
/// preview) and push a standalone form screen when one is tapped.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum _DesktopMode { login, signup }

class _WelcomeScreenState extends State<WelcomeScreen> {
  _DesktopMode _desktopMode = _DesktopMode.login;

  void _openLogin(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      setState(() => _desktopMode = _DesktopMode.login);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => LoginScreen(
        onBack: () => Navigator.of(routeContext).pop(),
        onSwitchToSignup: () => Navigator.of(routeContext).pushReplacement(
          MaterialPageRoute(builder: (c) => SignupScreen(onBack: () => Navigator.of(c).pop(), onSwitchToLogin: () => _openLogin(c))),
        ),
      ),
    ));
  }

  void _openSignup(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      setState(() => _desktopMode = _DesktopMode.signup);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => SignupScreen(
        onBack: () => Navigator.of(routeContext).pop(),
        onSwitchToLogin: () => Navigator.of(routeContext).pushReplacement(
          MaterialPageRoute(builder: (c) => LoginScreen(onBack: () => Navigator.of(c).pop(), onSwitchToSignup: () => _openSignup(c))),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      final isSignup = _desktopMode == _DesktopMode.signup;
      return Scaffold(
        backgroundColor: const Color(0xFF04070C),
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: AuthGradientPanel(mode: isSignup ? AuthPanelMode.signup : AuthPanelMode.login),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: isSignup
                        ? SignupForm(onSwitchToLogin: () => setState(() => _desktopMode = _DesktopMode.login))
                        : LoginForm(onSwitchToSignup: () => setState(() => _desktopMode = _DesktopMode.signup)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF04070C),
      body: AuthGradientPanel(
        mode: AuthPanelMode.welcome,
        onLoginTap: () => _openLogin(context),
        onSignupTap: () => _openSignup(context),
      ),
    );
  }
}
