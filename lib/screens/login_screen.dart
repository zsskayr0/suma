import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// Sign-in with the Supabase account's e-mail + password - works from any
/// device, not just the one the account was created on. [LoginForm] is the
/// reusable content (embedded directly in the desktop split view); this
/// [LoginScreen] wraps it as a standalone dark screen for mobile's pushed
/// navigation, where there's no room for the gradient panel beside it.
class LoginScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSwitchToSignup;
  const LoginScreen({super.key, required this.onBack, this.onSwitchToSignup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(onPressed: onBack),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: LoginForm(onSwitchToSignup: onSwitchToSignup),
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final VoidCallback? onSwitchToSignup;
  const LoginForm({super.key, this.onSwitchToSignup});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await context.read<AppState>().signIn(email: _emailCtrl.text, password: _passwordCtrl.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Entrar', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Entre com sua conta para continuar.', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5)),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailCtrl,
            style: authValueStyle,
            cursorColor: Colors.white,
            keyboardType: TextInputType.emailAddress,
            decoration: authFieldDecoration(label: 'E-mail', icon: HeroIcons.envelope),
            autocorrect: false,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            style: authValueStyle,
            cursorColor: Colors.white,
            obscureText: _obscure,
            decoration: authFieldDecoration(
              label: 'Senha',
              icon: HeroIcons.lockClosed,
              suffixIcon: IconButton(
                icon: HeroIcon(_obscure ? HeroIcons.eye : HeroIcons.eyeSlash, style: HeroIconStyle.outline, size: 18, color: Colors.white54),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Entrar'),
          ),
          if (widget.onSwitchToSignup != null) ...[
            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5),
                  children: [
                    const TextSpan(text: 'Não tem conta? '),
                    TextSpan(
                      text: 'Criar conta',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      recognizer: (TapGestureRecognizer()..onTap = widget.onSwitchToSignup),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
