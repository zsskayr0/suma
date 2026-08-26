import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../widgets/auth_field_style.dart';
import '../widgets/auth_gradient_panel.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// First screen shown when nobody is signed in.
///
/// Phone-width windows show the gradient hero panel (with the entry
/// buttons in place of the reference's step preview) and push a standalone
/// login/signup card when one is tapped. Desktop-width windows skip the
/// hero step and land straight on the same login card, centered on the
/// page - there's room to just toggle between login/signup locally instead
/// of a separate "choose" screen.
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
        backgroundColor: authPageColor(context),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AuthCard(
                child: isSignup
                    ? SignupForm(onSwitchToLogin: () => setState(() => _desktopMode = _DesktopMode.login))
                    : LoginForm(onSwitchToSignup: () => setState(() => _desktopMode = _DesktopMode.signup)),
              ),
            ),
          ),
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
