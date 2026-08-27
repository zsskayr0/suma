import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// The signup form's content - embedded directly under the Login/Cadastro
/// tab switcher in [WelcomeScreen], on both desktop and mobile. Family
/// linking ("criar minha rede" / "entrar com código") happens right after,
/// as the first step of [OnboardingScreen] - this only handles identity.
class SignupForm extends StatefulWidget {
  final VoidCallback? onSwitchToLogin;
  const SignupForm({super.key, this.onSwitchToLogin});

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
    final textColor = authTextColor(context);

    if (_awaitingEmailConfirmation) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, color: textColor.withValues(alpha: 0.06)),
            child: Center(child: HeroIcon(HeroIcons.envelopeOpen, style: HeroIconStyle.outline, size: 36, color: textColor)),
          ),
          const SizedBox(height: 18),
          Text('Confirme seu e-mail', style: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Enviamos um link de confirmação para ${_emailCtrl.text.trim()}. Depois de confirmar, volte aqui e entre na sua conta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: widget.onSwitchToLogin, child: const Text('Voltar')),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: 'Nome completo',
            controller: _nameCtrl,
            hint: 'Seu nome',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'E-mail',
            controller: _emailCtrl,
            hint: 'exemplo@gmail.com',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'Criar uma senha',
            controller: _passwordCtrl,
            hint: 'mínimo de 8 caracteres',
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: HeroIcon(_obscure ? HeroIcons.eyeSlash : HeroIcons.eye, style: HeroIconStyle.outline, size: 18, color: authMutedTextColor(context)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Mínimo de 8 caracteres' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'Confirmar senha',
            controller: _confirmCtrl,
            hint: 'repita a senha',
            obscureText: _obscure,
            validator: (v) => (v != _passwordCtrl.text) ? 'As senhas não coincidem' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: isAuthDark(context) ? Colors.white : Colors.black,
              foregroundColor: isAuthDark(context) ? Colors.black : Colors.white,
            ),
            child: _submitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: isAuthDark(context) ? Colors.black : Colors.white))
                : const Text('Criar conta'),
          ),
          const SizedBox(height: 18),
          const AuthOrDivider(text: 'Ou'),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: AuthSocialButton.facebook()),
              SizedBox(width: 10),
              Expanded(child: AuthSocialButton.google()),
              SizedBox(width: 10),
              Expanded(child: AuthSocialButton.apple()),
            ],
          ),
          if (widget.onSwitchToLogin != null) ...[
            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5),
                  children: [
                    const TextSpan(text: 'Já tem conta? '),
                    TextSpan(
                      text: 'Entrar',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
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
