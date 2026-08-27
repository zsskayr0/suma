import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/profile.dart';
import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/goal_trend.dart';
import '../widgets/suma_widgets.dart';

/// Admin-only tab: view every member of the family network and export
/// their CSV history (read-only - each person only ever edits their own
/// data; the admin can remove someone from the network, but never their
/// account, which they don't control). RLS on the backend already blocks a
/// non-admin from reading anyone else's rows - this screen is simply never
/// offered to them (see [HomeScreen]'s `showFamilyTab`).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _exportingAll = false;
  bool _loadingEntries = false;
  final Map<String, List<WeightEntry>> _entriesByMember = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    await appState.refreshFamilyMembers();
    if (!mounted) return;
    setState(() => _loadingEntries = true);
    final members = appState.familyMembers;
    final lists = await Future.wait(members.map((m) => appState.entriesFor(m.id)));
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < members.length; i++) {
        _entriesByMember[members[i].id] = lists[i];
      }
      _loadingEntries = false;
    });
  }

  Future<void> _exportMember(Profile member) async {
    final entries = _entriesByMember[member.id] ?? await context.read<AppState>().entriesFor(member.id);
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
      final entries = _entriesByMember[member.id] ?? await appState.entriesFor(member.id);
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
                    'Só você está nessa rede por enquanto.\nCompartilhe o código de convite em Perfil.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoalProximityCard(members: members, entriesByMember: _entriesByMember, loading: _loadingEntries),
                  const SizedBox(height: 14),
                  const SectionLabel('Membros'),
                  for (final member in members) ...[
                    _MemberCard(
                      member: member,
                      isSelf: member.id == appState.currentProfile?.id,
                      entries: _entriesByMember[member.id],
                      loading: _loadingEntries,
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

/// Ranks every member who has a goal set by how close they are to it - as a
/// percentage only, never the raw weights, so this stays comfortable to
/// look at for people who'd rather not broadcast actual numbers.
class _GoalProximityCard extends StatelessWidget {
  final List<Profile> members;
  final Map<String, List<WeightEntry>> entriesByMember;
  final bool loading;

  const _GoalProximityCard({required this.members, required this.entriesByMember, required this.loading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranked = <MapEntry<Profile, double>>[];
    for (final m in members) {
      final goal = m.goalWeightKg;
      final list = entriesByMember[m.id];
      if (goal == null || list == null || list.isEmpty) continue;
      final start = m.goalStartWeightKg ?? list.last.weightKg;
      final progress = goalProgressFraction(currentKg: list.first.weightKg, startKg: start, goalWeightKg: goal);
      ranked.add(MapEntry(m, progress));
    }
    ranked.sort((a, b) => b.value.compareTo(a.value));

    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppColors.goalAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Mais perto da meta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Só a porcentagem de progresso - sem mostrar o peso de ninguém.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (loading && ranked.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (ranked.isEmpty)
            Text('Ninguém definiu uma meta de peso ainda.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (final r in ranked) ...[
              _ProximityRow(name: r.key.name, progress: r.value),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ProximityRow extends StatelessWidget {
  final String name;
  final double progress;
  const _ProximityRow({required this.name, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.goalAccent),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GoalProgressBar(progress: progress, color: AppColors.goalAccent),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Profile member;
  final bool isSelf;
  final List<WeightEntry>? entries;
  final bool loading;
  final ColorScheme scheme;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.entries,
    required this.loading,
    required this.scheme,
    required this.onExport,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final list = entries;
    String stats;
    if (list == null) {
      stats = loading ? 'Carregando registros...' : '';
    } else {
      final cutoff = DateTime.now().subtract(const Duration(days: 60));
      final last60 = list.where((e) => !e.date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))).length;
      stats = '$last60 registro${last60 == 1 ? '' : 's'} nos últimos 60 dias · ${list.length} no total';
    }

    return SumaCard(
      child: Row(
        children: [
          UserAvatar(avatarUrl: member.avatarUrl, name: member.name, radius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(member.email ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(stats, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
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
