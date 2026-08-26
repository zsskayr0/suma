import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';

/// Dialog used by an admin to create a new managed account. Suggests a
/// random password (shown in clear, once) so the admin can hand it to the
/// person - nothing generated here is ever persisted anywhere but the
/// account's own salted hash.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const UserFormDialog());
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  late final TextEditingController _passwordCtrl;
  String _role = 'member';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController(text: AuthService.generateRandomPassword());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context.read<AppState>().createManagedUser(
          name: _nameCtrl.text,
          username: _usernameCtrl.text,
          password: _passwordCtrl.text,
          role: _role,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova conta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Usuário (login)'),
                autocorrect: false,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um usuário' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Senha inicial',
                  helperText: 'Gerada automaticamente - anote para repassar à pessoa.',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Gerar outra senha',
                    onPressed: () => setState(() => _passwordCtrl.text = AuthService.generateRandomPassword()),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Papel'),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Usuário')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'member'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _submit, child: const Text('Criar')),
      ],
    );
  }
}
