import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/auth_field_style.dart';

/// Password recovery, pushed from the login form's "Esqueceu a senha?".
/// Sends a real Supabase reset e-mail (a link, not a numeric code - the
/// project isn't set up for OTP-style recovery, so the copy reflects what
/// actually happens instead of promising something else).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final error = await context.read<AppState>().sendPasswordReset(_emailCtrl.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (error == null) {
        _sent = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = authTextColor(context);
    return Scaffold(
      backgroundColor: authPageColor(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundButton(icon: HeroIcons.chevronLeft, onTap: () => Navigator.of(context).pop()),
                      HeroIcon(HeroIcons.sparkles, style: HeroIconStyle.solid, size: 22, color: textColor),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_sent) ..._sentContent(context) else ..._formContent(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formContent(BuildContext context) {
    final textColor = authTextColor(context);
    return [
      Text('Esqueceu a senha?', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(
        'Não se preocupe! Acontece. Informe o e-mail associado à sua conta.',
        style: TextStyle(color: authMutedTextColor(context), fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 28),
      Form(
        key: _formKey,
        child: AuthLabeledField(
          label: 'E-mail',
          controller: _emailCtrl,
          hint: 'Digite seu e-mail',
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onFieldSubmitted: (_) => _submit(),
          validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
        ),
      ),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: isAuthDark(context) ? Colors.white : Colors.black,
          foregroundColor: isAuthDark(context) ? Colors.black : Colors.white,
        ),
        child: _submitting
            ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: isAuthDark(context) ? Colors.black : Colors.white))
            : const Text('Enviar link'),
      ),
      const SizedBox(height: 60),
      Center(
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: authMutedTextColor(context), fontSize: 13.5),
            children: [
              const TextSpan(text: 'Lembrou a senha? '),
              TextSpan(text: 'Entrar', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _sentContent(BuildContext context) {
    final textColor = authTextColor(context);
    return [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle, color: textColor.withValues(alpha: 0.06)),
        child: Center(child: HeroIcon(HeroIcons.envelopeOpen, style: HeroIconStyle.outline, size: 36, color: textColor)),
      ),
      const SizedBox(height: 20),
      Text('Verifique seu e-mail', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Text(
        'Se ${_emailCtrl.text.trim()} estiver associado a uma conta, enviamos um link para redefinir sua senha.',
        style: TextStyle(color: authMutedTextColor(context), fontSize: 14, height: 1.4),
      ),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: isAuthDark(context) ? Colors.white : Colors.black,
          foregroundColor: isAuthDark(context) ? Colors.black : Colors.white,
        ),
        child: const Text('Voltar para o login'),
      ),
    ];
  }
}

class _RoundButton extends StatelessWidget {
  final HeroIcons icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: authBorderColor(context)),
        ),
        child: Center(child: HeroIcon(icon, style: HeroIconStyle.outline, size: 18, color: authTextColor(context))),
      ),
    );
  }
}
