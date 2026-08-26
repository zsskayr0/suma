import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import 'entry_form_sheet.dart';

/// The main "Registros" tab: today's snapshot + full history for the
/// logged-in user.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.entries;
    final latest = entries.isNotEmpty ? entries.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Registros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => EntryFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo registro'),
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (latest != null) _LatestCard(entry: latest),
                const SizedBox(height: 16),
                Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final entry in entries) _EntryTile(entry: entry),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_weight_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Nenhum registro ainda', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Toque em "Novo registro" para começar a acompanhar seu peso.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  final WeightEntry entry;
  const _LatestCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _Stat(label: 'Peso', value: '${entry.weightKg} kg')),
            if (entry.bodyFatPct != null) Expanded(child: _Stat(label: 'Gordura', value: '${entry.bodyFatPct}%')),
            if (entry.hydrationPct != null) Expanded(child: _Stat(label: 'Hidratação', value: '${entry.hydrationPct}%')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final WeightEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final parts = <String>['${entry.weightKg} kg'];
    if (entry.bodyFatPct != null) parts.add('Gordura ${entry.bodyFatPct}%');
    if (entry.hydrationPct != null) parts.add('Hidratação ${entry.hydrationPct}%');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(DateFormat('dd/MM/yyyy').format(entry.date)),
        subtitle: Text(parts.join(' · ') + (entry.notes != null ? '\n${entry.notes}' : '')),
        isThreeLine: entry.notes != null,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              EntryFormSheet.show(context, existing: entry);
            } else if (value == 'delete') {
              _confirmDelete(context, entry);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WeightEntry entry) async {
    final appState = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: Text('O registro de ${DateFormat('dd/MM/yyyy').format(entry.date)} será removido permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.deleteEntry(entry.id!);
    }
  }
}
