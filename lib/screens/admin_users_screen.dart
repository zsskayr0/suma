import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../services/csv_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/family_heatmap.dart';
import '../widgets/suma_widgets.dart';

/// "Usuários" tab: the same screen for everyone in the family network -
/// who's in it (name, photo, role), the goal-proximity ranking and the
/// contribution heatmap are all visible to any member, not just the admin.
/// Those two only ever show a percentage/count, computed server-side by a
/// SECURITY DEFINER RPC that never returns anyone's actual weight - a
/// regular member still can't read another member's raw `weight_entries`
/// row (that stays admin-only, enforced by RLS, not just hidden here).
/// What *is* still admin-only here: exporting someone else's full CSV and
/// removing a member from the network - both need either the raw data or
/// real authority over the network, not just an aggregate view of it.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _exportingAll = false;
  bool _loadingAggregates = false;
  Map<String, ({int total, int recent})> _entryCounts = {};
  List<({String id, String name, double progress})> _goalProgress = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    await appState.refreshFamilyMembers();
    if (!mounted || appState.familyMembers.length <= 1) return;
    setState(() => _loadingAggregates = true);
    final counts = await appState.familyEntryCounts();
    final progress = await appState.familyGoalProgress();
    if (!mounted) return;
    setState(() {
      _entryCounts = counts;
      _goalProgress = progress;
      _loadingAggregates = false;
    });
  }

  Future<void> _exportMember(Profile member) async {
    final entries = await context.read<AppState>().entriesFor(member.id);
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
    final isAdmin = appState.currentProfile?.isAdmin ?? false;
    final showAggregates = members.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.currentFamily?.name ?? 'Usuários'),
        actions: [
          if (isAdmin && members.isNotEmpty)
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
                  if (showAggregates) ...[
                    _GoalProximityCard(ranking: _goalProgress, loading: _loadingAggregates),
                    const SizedBox(height: 14),
                    const FamilyHeatmap(),
                    const SizedBox(height: 14),
                  ],
                  const SectionLabel('Membros'),
                  for (final member in members) ...[
                    _MemberCard(
                      member: member,
                      isSelf: member.id == appState.currentProfile?.id,
                      isAdmin: isAdmin,
                      counts: _entryCounts[member.id],
                      loading: _loadingAggregates,
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
/// look at for people who'd rather not broadcast actual numbers. Computed
/// server-side (see `family_goal_progress` RPC), so this is safe to show
/// to any member, not just the admin.
class _GoalProximityCard extends StatelessWidget {
  final List<({String id, String name, double progress})> ranking;
  final bool loading;

  const _GoalProximityCard({required this.ranking, required this.loading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranked = [...ranking]..sort((a, b) => b.progress.compareTo(a.progress));

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
          const SizedBox(height: 14),
          if (loading && ranked.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (ranked.isEmpty)
            Text('Ninguém definiu uma meta de peso ainda.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (final r in ranked) ...[
              _ProximityRow(name: r.name, progress: r.progress),
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
  final bool isAdmin;
  final ({int total, int recent})? counts;
  final bool loading;
  final ColorScheme scheme;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isSelf,
    required this.isAdmin,
    required this.counts,
    required this.loading,
    required this.scheme,
    required this.onExport,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    String stats = '';
    if (counts != null) {
      final c = counts!;
      stats = '${c.recent} registro${c.recent == 1 ? '' : 's'} nos últimos 60 dias · ${c.total} no total';
    } else if (loading) {
      stats = 'Carregando registros...';
    }

    return SumaCard(
      child: Row(
        children: [
          UserAvatar(avatarUrl: member.avatarUrl, name: member.name, radius: 22, isAdmin: member.isAdmin),
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
          Pill(text: member.isAdmin ? 'Admin' : 'Membro', color: AppColors.roleRing(member.isAdmin)),
          if (isAdmin) ...[
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
        ],
      ),
    );
  }
}
