import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';
import 'forgot_password_screen.dart';

/// The login form's content - embedded directly under the Login/Cadastro
/// tab switcher in [WelcomeScreen], on both desktop and mobile.
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
  bool _rememberMe = true;
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
    // Tells Android's autofill service (Proton Pass, Google, etc.) the
    // login attempt is done - without this it never offers to save the
    // credentials, even with autofillHints set on the fields.
    TextInput.finishAutofillContext(shouldSave: error == null);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = authTextColor(context);
    return Form(
      key: _formKey,
      // Groups the two fields as one login form for Android's autofill
      // service - without it, hints on individual fields aren't enough to
      // get a "save password?" prompt.
      child: AutofillGroup(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: 'E-mail',
            controller: _emailCtrl,
            hint: 'Seu e-mail',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'Senha',
            controller: _passwordCtrl,
            hint: 'Senha',
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            suffixIcon: IconButton(
              icon: HeroIcon(_obscure ? HeroIcons.eyeSlash : HeroIcons.eye, style: HeroIconStyle.outline, size: 18, color: authMutedTextColor(context)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  activeColor: isAuthDark(context) ? Colors.white : Colors.black,
                  checkColor: isAuthDark(context) ? Colors.black : Colors.white,
                  side: BorderSide(color: authBorderColor(context).withValues(alpha: 0.6)),
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 8),
              Text('Lembrar de mim', style: TextStyle(color: authMutedTextColor(context), fontSize: 13)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Esqueceu a senha?', style: TextStyle(color: authMutedTextColor(context), fontSize: 13)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
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
                : const Text('Entrar'),
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
          if (widget.onSwitchToSignup != null) ...[
            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5),
                  children: [
                    const TextSpan(text: 'Não tem conta? '),
                    TextSpan(
                      text: 'Cadastre-se',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                      recognizer: (TapGestureRecognizer()..onTap = widget.onSwitchToSignup),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
