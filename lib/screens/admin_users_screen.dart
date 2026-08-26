import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import 'user_form_dialog.dart';

/// Admin-only tab: create/manage every other account, reset passwords, and
/// export any single user's (or every user's) CSV history.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _exportingAll = false;

  Future<void> _exportUser(AppUser user) async {
    final appState = context.read<AppState>();
    final entries = await appState.entriesFor(user.id!);
    final file = await CsvExportService.exportAndHandOff(user, entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV de ${user.name} salvo em: ${file.path}')),
    );
  }

  Future<void> _exportAll() async {
    setState(() => _exportingAll = true);
    final appState = context.read<AppState>();
    for (final user in appState.users) {
      final entries = await appState.entriesFor(user.id!);
      await CsvExportService.writeCsvFile(user, entries);
    }
    if (!mounted) return;
    setState(() => _exportingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Um CSV por usuário foi salvo na pasta Suma/exports.')),
    );
  }

  Future<void> _resetPassword(AppUser user) async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Redefinir senha de ${user.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nova senha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Redefinir')),
        ],
      ),
    );
    if (newPassword == null || newPassword.length < 6) return;
    if (!mounted) return;
    await context.read<AppState>().resetPassword(user, newPassword);
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover conta?'),
        content: Text('A conta de ${user.name} e todo o histórico de registros dela serão excluídos permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final error = await context.read<AppState>().deleteManagedUser(user);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final users = appState.users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV de todos',
            icon: _exportingAll
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.folder_zip_outlined),
            onPressed: _exportingAll ? null : _exportAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => UserFormDialog.show(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nova conta'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final isSelf = user.id == appState.currentUser?.id;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(user.name.trim().isEmpty ? '?' : user.name.trim()[0].toUpperCase())),
              title: Text(user.name),
              subtitle: Text('${user.username} · ${user.isAdmin ? 'Administrador' : 'Usuário'}${isSelf ? ' · você' : ''}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportUser(user);
                      break;
                    case 'reset':
                      _resetPassword(user);
                      break;
                    case 'delete':
                      _deleteUser(user);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'export', child: Text('Exportar CSV')),
                  const PopupMenuItem(value: 'reset', child: Text('Redefinir senha')),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !isSelf,
                    child: const Text('Remover conta'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
