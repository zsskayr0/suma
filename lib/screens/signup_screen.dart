import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// Creates a brand-new Supabase account. Family linking ("criar minha rede"
/// / "entrar com código") happens right after, as the first step of
/// [OnboardingScreen] - this screen only handles identity. [SignupForm] is
/// the reusable content (embedded in the desktop split view); [SignupScreen]
/// wraps it as a standalone dark screen for mobile's pushed navigation.
class SignupScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSwitchToLogin;
  const SignupScreen({super.key, required this.onBack, this.onSwitchToLogin});

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
            child: SignupForm(onBack: onBack, onSwitchToLogin: onSwitchToLogin),
          ),
        ),
      ),
    );
  }
}

class SignupForm extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSwitchToLogin;
  const SignupForm({super.key, this.onBack, this.onSwitchToLogin});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  bool _awaitingEmailConfirmation = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await context.read<AppState>().signUp(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result == 'CONFIRM_EMAIL') {
        _awaitingEmailConfirmation = true;
        _error = null;
      } else {
        _error = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingEmailConfirmation) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            child: const Center(child: HeroIcon(HeroIcons.envelopeOpen, style: HeroIconStyle.outline, size: 38, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          const Text('Confirme seu e-mail', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Enviamos um link de confirmação para ${_emailCtrl.text.trim()}. Depois de confirmar, volte aqui e entre na sua conta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: widget.onBack ?? widget.onSwitchToLogin, child: const Text('Voltar')),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Criar conta', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Preencha seus dados para começar.', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5)),
          const SizedBox(height: 28),
          TextFormField(
            controller: _nameCtrl,
            style: authValueStyle,
            cursorColor: Colors.white,
            decoration: authFieldDecoration(label: 'Nome completo', icon: HeroIcons.userCircle),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            style: authValueStyle,
            cursorColor: Colors.white,
            keyboardType: TextInputType.emailAddress,
            decoration: authFieldDecoration(label: 'E-mail', icon: HeroIcons.envelope),
            autocorrect: false,
            validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
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
            validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            style: authValueStyle,
            cursorColor: Colors.white,
            obscureText: _obscure,
            decoration: authFieldDecoration(label: 'Confirmar senha', icon: HeroIcons.lockClosed),
            validator: (v) => (v != _passwordCtrl.text) ? 'As senhas não coincidem' : null,
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
                : const Text('Criar conta'),
          ),
          if (widget.onSwitchToLogin != null) ...[
            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5),
                  children: [
                    const TextSpan(text: 'Já tem conta? '),
                    TextSpan(
                      text: 'Entrar',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      recognizer: (TapGestureRecognizer()..onTap = widget.onSwitchToLogin),
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
