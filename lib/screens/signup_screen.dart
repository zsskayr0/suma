import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// Creates a brand-new Supabase account. Family linking ("criar minha rede"
/// / "entrar com código") happens right after, as the first step of
/// [OnboardingScreen] - this screen only handles identity. [SignupForm] is
/// the reusable content (embedded directly on desktop); [SignupScreen] wraps
/// it as a standalone screen for mobile's pushed navigation.
class SignupScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSwitchToLogin;
  const SignupScreen({super.key, required this.onBack, this.onSwitchToLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authPageColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: authTextColor(context),
        elevation: 0,
        leading: BackButton(onPressed: onBack),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AuthCard(child: SignupForm(onBack: onBack, onSwitchToLogin: onSwitchToLogin)),
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
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  bool _awaitingEmailConfirmation = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
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
    final name = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
    final result = await context.read<AppState>().signUp(
          name: name,
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
            width: 88,
            height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: textColor.withValues(alpha: 0.06)),
            child: Center(child: HeroIcon(HeroIcons.envelopeOpen, style: HeroIconStyle.outline, size: 38, color: textColor)),
          ),
          const SizedBox(height: 20),
          Text('Confirme seu e-mail', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Enviamos um link de confirmação para ${_emailCtrl.text.trim()}. Depois de confirmar, volte aqui e entre na sua conta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5, height: 1.5),
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
          Text('Criar conta', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Preencha seus dados para criar sua conta.', style: TextStyle(color: authMutedTextColor(context), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: AuthSocialButton.google()),
              const SizedBox(width: 10),
              const Expanded(child: AuthSocialButton.apple()),
            ],
          ),
          const SizedBox(height: 18),
          const AuthOrDivider(text: 'Ou'),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AuthLabeledField(
                  label: 'Nome',
                  controller: _firstNameCtrl,
                  hint: 'ex: João',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuthLabeledField(
                  label: 'Sobrenome',
                  controller: _lastNameCtrl,
                  hint: 'ex: Silva',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'E-mail',
            controller: _emailCtrl,
            hint: 'ex: joao@gmail.com',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'Senha',
            controller: _passwordCtrl,
            hint: 'Digite sua senha',
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: HeroIcon(_obscure ? HeroIcons.eye : HeroIcons.eyeSlash, style: HeroIconStyle.outline, size: 18, color: authMutedTextColor(context)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Mínimo de 8 caracteres' : null,
          ),
          const SizedBox(height: 6),
          Text('Deve ter pelo menos 8 caracteres.', style: TextStyle(color: authMutedTextColor(context), fontSize: 11.5)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13)),
          ],
          const SizedBox(height: 22),
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
