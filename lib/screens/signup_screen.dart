import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/suma_widgets.dart';

/// Creates a brand-new Supabase account. Family linking ("criar minha rede"
/// / "entrar com código") happens right after, as the first step of
/// [OnboardingScreen] - this screen only handles identity.
class SignupScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SignupScreen({super.key, required this.onBack});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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
    final scheme = Theme.of(context).colorScheme;

    if (_awaitingEmailConfirmation) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                Text('Confirme seu e-mail', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Enviamos um link de confirmação para ${_emailCtrl.text.trim()}. Depois de confirmar, volte aqui e toque em Entrar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: widget.onBack, child: const Text('Voltar')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Criar conta', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                          autocorrect: false,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          decoration: const InputDecoration(labelText: 'Confirmar senha', prefixIcon: Icon(Icons.lock_outline_rounded)),
                          validator: (v) => (v != _passwordCtrl.text) ? 'As senhas não coincidem' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: scheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Criar conta'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
