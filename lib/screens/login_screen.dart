import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// Sign-in with the Supabase account's e-mail + password - works from any
/// device, not just the one the account was created on. [LoginForm] is the
/// reusable content (embedded directly on desktop); this [LoginScreen] wraps
/// it as a standalone screen for mobile's pushed navigation.
class LoginScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSwitchToSignup;
  const LoginScreen({super.key, required this.onBack, this.onSwitchToSignup});

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
            child: AuthCard(child: LoginForm(onSwitchToSignup: onSwitchToSignup)),
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

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailCtrl.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail da sua conta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Enviar')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;
    final error = await context.read<AppState>().sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Enviamos um link de recuperação para $email.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = authTextColor(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bem-vindo(a) de volta!', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Informe seus dados para entrar na sua conta', style: TextStyle(color: authMutedTextColor(context), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const AuthSocialButton.google(),
          const SizedBox(height: 10),
          const AuthSocialButton.apple(),
          const SizedBox(height: 18),
          const AuthOrDivider(text: 'Ou entre com', withLines: false),
          const SizedBox(height: 18),
          AuthLabeledField(
            label: 'E-mail',
            controller: _emailCtrl,
            hint: 'ex: joao@gmail.com',
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
          ),
          const SizedBox(height: 14),
          AuthLabeledField(
            label: 'Senha',
            controller: _passwordCtrl,
            hint: 'mínimo de 8 caracteres',
            obscureText: _obscure,
            suffixIcon: IconButton(
              icon: HeroIcon(_obscure ? HeroIcons.eye : HeroIcons.eyeSlash, style: HeroIconStyle.outline, size: 18, color: authMutedTextColor(context)),
              onPressed: () => setState(() => _obscure = !_obscure),
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
            style: FilledButton.styleFrom(
              backgroundColor: isAuthDark(context) ? Colors.white : Colors.black,
              foregroundColor: isAuthDark(context) ? Colors.black : Colors.white,
            ),
            child: _submitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: isAuthDark(context) ? Colors.black : Colors.white))
                : const Text('Entrar'),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _forgotPassword,
              child: Text('Esqueceu a senha?', style: TextStyle(color: authMutedTextColor(context), fontSize: 13)),
            ),
          ),
          if (widget.onSwitchToSignup != null) ...[
            const SizedBox(height: 6),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5),
                  children: [
                    const TextSpan(text: 'Não tem conta? '),
                    TextSpan(
                      text: 'Criar conta',
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
    );
  }
}
