import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/csv_export_service.dart';
import '../state/app_state.dart';

/// "Conta" tab, available to every account: export your own data, change
/// your own password, sign out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _exporting = false;

  Future<void> _exportMyData() async {
    setState(() => _exporting = true);
    final appState = context.read<AppState>();
    final user = appState.currentUser!;
    final file = await CsvExportService.exportAndHandOff(user, appState.entries);
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV salvo em: ${file.path}')),
    );
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar senha'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nova senha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (newPassword == null) return;
    if (newPassword.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A senha deve ter ao menos 6 caracteres.')),
      );
      return;
    }
    if (!mounted) return;
    final appState = context.read<AppState>();
    await appState.resetPassword(appState.currentUser!, newPassword);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.name),
              subtitle: Text('${user.username} · ${user.isAdmin ? 'Administrador' : 'Usuário'}'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: _exporting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
              title: const Text('Exportar meus dados (CSV)'),
              subtitle: const Text('Data, peso, gordura e hidratação'),
              onTap: _exporting ? null : _exportMyData,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Alterar senha'),
              onTap: _changePassword,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => appState.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
