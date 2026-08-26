import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import '../widgets/suma_widgets.dart';
import 'entry_form_sheet.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} de ${d.year}';

/// "Histórico" tab: every entry ever logged (the dashboard only shows the
/// last 30 days), grouped by month, with a quick period filter and simple
/// min/avg/max stats for whatever period is selected.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _filterDays; // null = tudo

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final unitPref = appState.currentProfile?.unitPref ?? 'kg';
    final all = appState.entries; // date DESC, id DESC

    List<WeightEntry> filtered = all;
    if (_filterDays != null && all.isNotEmpty) {
      final cutoff = all.first.date.subtract(Duration(days: _filterDays!));
      filtered = all.where((e) => !e.date.isBefore(cutoff)).toList();
    }

    final groups = <String, List<WeightEntry>>{};
    for (final e in filtered) {
      final key = _monthLabel(DateTime(e.date.year, e.date.month));
      groups.putIfAbsent(key, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => EntryFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo registro'),
      ),
      body: all.isEmpty
          ? Center(
              child: Text('Nenhum registro ainda', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodFilter(selected: _filterDays, onChanged: (v) => setState(() => _filterDays = v)),
                  const SizedBox(height: 14),
                  if (filtered.isNotEmpty) _SummaryRow(entries: filtered, unitPref: unitPref),
                  const SizedBox(height: 18),
                  for (final entry in groups.entries) ...[
                    SectionLabel(entry.key),
                    for (final e in entry.value) _HistoryTile(entry: e, unitPref: unitPref),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _PeriodFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = <String, int?>{'7 dias': 7, '30 dias': 30, '90 dias': 90, 'Tudo': null};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options.entries) ...[
            ChoiceChip(
              label: Text(o.key),
              selected: selected == o.value,
              onSelected: (_) => onChanged(o.value),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<WeightEntry> entries;
  final String unitPref;
  const _SummaryRow({required this.entries, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final values = entries.map((e) => e.weightKg).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    return StatGrid(
      children: [
        StatTile(icon: Icons.show_chart_rounded, color: Theme.of(context).colorScheme.primary, label: 'Média', value: Units.formatWithUnit(avg, unitPref)),
        StatTile(icon: Icons.arrow_downward_rounded, color: AppColors.positive, label: 'Mínimo', value: Units.formatWithUnit(min, unitPref)),
        StatTile(icon: Icons.arrow_upward_rounded, color: AppColors.negative, label: 'Máximo', value: Units.formatWithUnit(max, unitPref)),
        StatTile(icon: Icons.numbers_rounded, color: AppColors.hydrationAccent, label: 'Registros', value: '${entries.length}'),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WeightEntry entry;
  final String unitPref;
  const _HistoryTile({required this.entry, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SumaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () => EntryFormSheet.show(context, existing: entry),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.monitor_weight_outlined, color: scheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Units.formatWithUnit(entry.weightKg, unitPref), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      DateFormat('dd/MM/yyyy').format(entry.date),
                      if (entry.bodyFatPct != null) 'Gordura ${entry.bodyFatPct!.toStringAsFixed(1)}%',
                      if (entry.hydrationPct != null) 'Hidratação ${entry.hydrationPct!.toStringAsFixed(1)}%',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (entry.notes != null) ...[
                    const SizedBox(height: 2),
                    Text(entry.notes!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
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
