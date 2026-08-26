import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/suma_widgets.dart';

/// Admin-only tab: view every member of the family network and export
/// their CSV history (read-only - each person only ever edits their own
/// data; the admin can remove someone from the network, but never their
/// account, which they don't control).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _exportingAll = false;

  Future<void> _exportMember(Profile member) async {
    final appState = context.read<AppState>();
    final entries = await appState.entriesFor(member.id);
    final file = await CsvExportService.exportAndHandOff(member, entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV de ${member.name} salvo em: ${file.path}')),
    );
  }

  Future<void> _exportAll() async {
    setState(() => _exportingAll = true);
    final appState = context.read<AppState>();
    for (final member in appState.familyMembers) {
      final entries = await appState.entriesFor(member.id);
      await CsvExportService.writeCsvFile(member, entries);
    }
    if (!mounted) return;
    setState(() => _exportingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Um CSV por membro foi salvo na pasta Suma/exports.')),
    );
  }

  Future<void> _removeMember(Profile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da rede?'),
        content: Text('${member.name} deixará de fazer parte da sua rede familiar. A conta e o histórico dela continuam intactos - só param de ser visíveis para você.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final error = await context.read<AppState>().removeFamilyMember(member.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final members = appState.familyMembers;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.currentFamily?.name ?? 'Usuários'),
        actions: [
          if (members.isNotEmpty)
            IconButton(
              tooltip: 'Exportar CSV de todos',
              icon: _exportingAll
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_zip_outlined),
              onPressed: _exportingAll ? null : _exportAll,
            ),
        ],
      ),
      body: ResponsiveBody(
        child: members.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Só você está nessa rede por enquanto.\nCompartilhe o código de convite em Ajustes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final member in members) ...[
                    _MemberCard(
                      member: member,
                      isSelf: member.id == appState.currentProfile?.id,
                      scheme: scheme,
                      onExport: () => _exportMember(member),
                      onRemove: () => _removeMember(member),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Profile member;
  final bool isSelf;
  final ColorScheme scheme;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.scheme,
    required this.onExport,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SumaCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.16),
            child: Text(
              member.name.trim().isEmpty ? '?' : member.name.trim()[0].toUpperCase(),
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${member.email ?? ''}${isSelf ? ' · você' : ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Pill(text: member.isAdmin ? 'Admin' : 'Membro', color: member.isAdmin ? AppColors.goalAccent : scheme.primary),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  onExport();
                  break;
                case 'remove':
                  onRemove();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: Text('Exportar CSV')),
              PopupMenuItem(value: 'remove', enabled: !isSelf, child: const Text('Remover da rede')),
            ],
          ),
        ],
      ),
    );
  }
}
