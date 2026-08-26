import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/goal_trend.dart';
import '../utils/units.dart';
import '../widgets/suma_widgets.dart';
import '../widgets/weight_line_chart.dart';
import 'entry_form_sheet.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} de ${d.year}';

/// One row ready to render: the entry, who it belongs to, and its change
/// vs. that same person's previous entry (computed against their full,
/// unfiltered history - not just whatever the period filter shows).
class _Row {
  final WeightEntry entry;
  final Profile owner;
  final double? deltaKg;
  final double? previousWeightKg;
  const _Row({required this.entry, required this.owner, required this.deltaKg, required this.previousWeightKg});
}

/// "Histórico" tab: every entry ever logged (the dashboard only shows the
/// last 30 days) with a period filter, a trend chart and a change indicator
/// per entry. A family admin can additionally pick which member(s) to look
/// at - selecting more than one overlays them on the same chart and tags
/// every row with whose entry it is, for comparison.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _filterDays;
  Set<String>? _selectedUserIds; // null until initState knows "self"
  final Map<String, List<WeightEntry>> _othersEntries = {};
  bool _loadingOthers = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _selectedUserIds = {appState.currentProfile!.id};
    // Picks up members who joined/left since this session started - there's
    // no realtime subscription, so a fresh look each time this tab opens is
    // the next best thing.
    appState.refreshFamilyMembers();
  }

  Future<void> _ensureLoaded(String userId, AppState appState) async {
    if (userId == appState.currentProfile!.id || _othersEntries.containsKey(userId)) return;
    setState(() => _loadingOthers = true);
    final entries = await appState.entriesFor(userId);
    if (!mounted) return;
    setState(() {
      _othersEntries[userId] = entries;
      _loadingOthers = false;
    });
  }

  void _toggleUser(String id, AppState appState) {
    final selected = _selectedUserIds!;
    setState(() {
      if (selected.contains(id)) {
        if (selected.length > 1) selected.remove(id);
      } else {
        selected.add(id);
      }
    });
    _ensureLoaded(id, appState);
  }

  List<WeightEntry> _fullEntriesFor(String id, AppState appState) {
    if (id == appState.currentProfile!.id) return appState.entries; // date DESC
    return _othersEntries[id] ?? const [];
  }

  double? _previousWeightAt(List<WeightEntry> descList, int index) {
    if (index + 1 >= descList.length) return null;
    return descList[index + 1].weightKg;
  }

  DateTime? get _cutoff => _filterDays == null ? null : DateTime.now().subtract(Duration(days: _filterDays!));

  bool _withinFilter(DateTime date) {
    final cutoff = _cutoff;
    if (cutoff == null) return true;
    return !date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selfProfile = appState.currentProfile!;
    final unitPref = selfProfile.unitPref;
    final canPickMembers = selfProfile.isAdmin && appState.familyMembers.length > 1;
    final pickable = canPickMembers ? appState.familyMembers : [selfProfile];
    final selected = _selectedUserIds!.intersection(pickable.map((p) => p.id).toSet());
    if (selected.isEmpty) selected.add(selfProfile.id);

    // Per-person color, stable by position in `pickable` (sorted by name).
    Color colorFor(String id) => AppColors.seriesColor(pickable.indexWhere((p) => p.id == id));

    final rows = <_Row>[];
    final chartSeries = <ChartSeries>[];
    for (final owner in pickable.where((p) => selected.contains(p.id))) {
      final full = _fullEntriesFor(owner.id, appState); // DESC
      final filteredAsc = <WeightEntry>[];
      for (var i = 0; i < full.length; i++) {
        final e = full[i];
        if (!_withinFilter(e.date)) continue;
        final previousWeightKg = _previousWeightAt(full, i);
        rows.add(_Row(entry: e, owner: owner, deltaKg: previousWeightKg == null ? null : e.weightKg - previousWeightKg, previousWeightKg: previousWeightKg));
        filteredAsc.add(e);
      }
      if (filteredAsc.isNotEmpty) {
        chartSeries.add(ChartSeries(label: owner.name, color: colorFor(owner.id), entries: filteredAsc.reversed.toList()));
      }
    }
    rows.sort((a, b) {
      final byDate = b.entry.date.compareTo(a.entry.date);
      return byDate != 0 ? byDate : a.owner.name.compareTo(b.owner.name);
    });

    final groups = <String, List<_Row>>{};
    for (final row in rows) {
      final key = _monthLabel(DateTime(row.entry.date.year, row.entry.date.month));
      groups.putIfAbsent(key, () => []).add(row);
    }

    final showOwner = selected.length > 1;
    final hasAnyData = appState.entries.isNotEmpty || _othersEntries.values.any((l) => l.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => EntryFormSheet.show(context),
        tooltip: 'Novo registro',
        child: const Icon(Icons.add),
      ),
      body: !hasAnyData
          ? Center(
              child: Text('Nenhum registro ainda', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPickMembers) ...[
                    _MemberPicker(
                      members: pickable,
                      selected: selected,
                      colorFor: colorFor,
                      onToggle: (id) => _toggleUser(id, appState),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loadingOthers) const LinearProgressIndicator(minHeight: 2),
                  _PeriodFilter(selected: _filterDays, onChanged: (v) => setState(() => _filterDays = v)),
                  const SizedBox(height: 14),
                  SumaCard(
                    child: WeightLineChart(series: chartSeries, unitPref: unitPref),
                  ),
                  const SizedBox(height: 14),
                  if (selected.length == 1 && rows.isNotEmpty) _SummaryRow(entries: rows.map((r) => r.entry).toList(), unitPref: unitPref),
                  const SizedBox(height: 18),
                  for (final entry in groups.entries) ...[
                    SectionLabel(entry.key),
                    for (final row in entry.value)
                      _HistoryTile(
                        row: row,
                        unitPref: unitPref,
                        showOwner: showOwner,
                        ownerColor: colorFor(row.owner.id),
                        isSelf: row.owner.id == selfProfile.id,
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MemberPicker extends StatelessWidget {
  final List<Profile> members;
  final Set<String> selected;
  final Color Function(String id) colorFor;
  final ValueChanged<String> onToggle;

  const _MemberPicker({required this.members, required this.selected, required this.colorFor, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final member in members) ...[
            FilterChip(
              label: Text(member.name),
              avatar: CircleAvatar(backgroundColor: colorFor(member.id), radius: 6),
              selected: selected.contains(member.id),
              onSelected: (_) => onToggle(member.id),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            const SizedBox(width: 8),
          ],
        ],
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
    final options = <String, int?>{'30 dias': 30, '90 dias': 90, '6 meses': 182, '1 ano': 365, 'Tudo': null};
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
  final _Row row;
  final String unitPref;
  final bool showOwner;
  final Color ownerColor;
  final bool isSelf;
  const _HistoryTile({required this.row, required this.unitPref, required this.showOwner, required this.ownerColor, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = row.entry;
    final deltaKg = row.deltaKg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SumaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: isSelf ? () => EntryFormSheet.show(context, existing: entry) : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (showOwner ? ownerColor : scheme.primary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.monitor_weight_outlined, color: showOwner ? ownerColor : scheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(Units.formatWithUnit(entry.weightKg, unitPref), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (deltaKg != null && row.previousWeightKg != null) ...[
                        const SizedBox(width: 8),
                        _DeltaPill(
                          deltaKg: deltaKg,
                          unitPref: unitPref,
                          previousWeightKg: row.previousWeightKg!,
                          currentWeightKg: entry.weightKg,
                          goalWeightKg: row.owner.goalWeightKg,
                          goalType: row.owner.goalType,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      DateFormat('dd/MM/yyyy').format(entry.date),
                      if (showOwner) row.owner.name,
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
            if (isSelf)
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

class _DeltaPill extends StatelessWidget {
  final double deltaKg;
  final String unitPref;
  final double previousWeightKg;
  final double currentWeightKg;
  final double? goalWeightKg;
  final String goalType;

  const _DeltaPill({
    required this.deltaKg,
    required this.unitPref,
    required this.previousWeightKg,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.goalType,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (deltaKg == 0) {
      return Pill(text: '0 ${Units.label(unitPref)}', color: scheme.outline, icon: Icons.trending_flat_rounded);
    }
    final losing = deltaKg < 0;
    final sign = losing ? '-' : '+';
    final positive = goalTrendPositive(fromKg: previousWeightKg, toKg: currentWeightKg, goalWeightKg: goalWeightKg, goalType: goalType);
    return Pill(
      text: '$sign${Units.displayValue(deltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}',
      color: positive == false ? AppColors.negative : AppColors.positive,
      icon: losing ? Icons.trending_down_rounded : Icons.trending_up_rounded,
    );
  }
}
