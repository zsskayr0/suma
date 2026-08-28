import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/pet.dart';
import '../models/pet_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';
import '../widgets/period_filter.dart';
import '../widgets/suma_glass_sheet.dart';
import '../widgets/suma_widgets.dart';
import '../widgets/weight_line_chart.dart';
import 'pet_entry_form_sheet.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} de ${d.year}';

class _PetRow {
  final PetWeightEntry entry;
  final Pet pet;
  final double? deltaKg;
  final double? previousWeightKg;
  const _PetRow({required this.entry, required this.pet, required this.deltaKg, required this.previousWeightKg});
}

/// "Histórico" pro pet, aberto tanto de Ajustes > Pets quanto de Usuários >
/// Pets - mesma estrutura da tela de Histórico humana (gráfico, filtro de
/// período, resumo, lista por mês), só que o seletor no topo troca pessoas
/// por pets. [pickablePets] já vem pré-filtrado por quem pode ver o quê
/// (todo mundo só pode ver os próprios - exceto o admin da rede, que vê os
/// de todos - ver AppState.pets) - esta tela não decide isso, só mostra o
/// que recebeu.
class PetHistoryScreen extends StatefulWidget {
  final List<Pet> pickablePets;
  final String initialPetId;

  const PetHistoryScreen({super.key, required this.pickablePets, required this.initialPetId});

  @override
  State<PetHistoryScreen> createState() => _PetHistoryScreenState();
}

class _PetHistoryScreenState extends State<PetHistoryScreen> {
  int? _filterDays;
  late final Set<String> _selectedPetIds = {widget.initialPetId};
  final Map<String, List<PetWeightEntry>> _entriesCache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ensureLoaded(widget.initialPetId);
  }

  Future<void> _ensureLoaded(String petId) async {
    if (_entriesCache.containsKey(petId)) return;
    setState(() => _loading = true);
    final entries = await context.read<AppState>().petEntriesFor(petId);
    if (!mounted) return;
    setState(() {
      _entriesCache[petId] = entries;
      _loading = false;
    });
  }

  void _togglePet(String id) {
    setState(() {
      if (_selectedPetIds.contains(id)) {
        if (_selectedPetIds.length > 1) _selectedPetIds.remove(id);
      } else {
        _selectedPetIds.add(id);
      }
    });
    _ensureLoaded(id);
  }

  double? _previousWeightAt(List<PetWeightEntry> descList, int index) {
    if (index + 1 >= descList.length) return null;
    return descList[index + 1].weightKg;
  }

  DateTime? get _cutoff => _filterDays == null ? null : DateTime.now().subtract(Duration(days: _filterDays!));

  bool _withinFilter(DateTime date) {
    final cutoff = _cutoff;
    if (cutoff == null) return true;
    return !date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
  }

  Future<void> _addEntry(Pet pet, AppState appState) async {
    final saved = await PetEntryFormSheet.show(context, petId: pet.id!, petName: pet.name, unitPref: appState.currentProfile!.unitPref);
    if (saved == true) {
      _entriesCache.remove(pet.id);
      await _ensureLoaded(pet.id!);
    }
  }

  Future<void> _confirmDelete(PetWeightEntry entry, Pet pet) async {
    final appState = context.read<AppState>();
    final confirmed = await showSumaGlassSheet<bool>(
      context,
      maxWidth: 360,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Excluir registro?', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'O registro de ${DateFormat('dd/MM/yyyy').format(entry.date)} de ${pet.name} será removido permanentemente.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
                    child: const Text('Excluir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await appState.deletePetEntry(entry.id!);
      _entriesCache.remove(pet.id);
      await _ensureLoaded(pet.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final unitPref = appState.currentProfile!.unitPref;
    final pets = [...widget.pickablePets]..sort((a, b) => a.name.compareTo(b.name));
    final selected = _selectedPetIds.intersection(pets.map((p) => p.id!).toSet());
    if (selected.isEmpty && pets.isNotEmpty) selected.add(pets.first.id!);

    Color colorFor(String id) => AppColors.seriesColor(pets.indexWhere((p) => p.id == id));
    String ownerNameFor(String ownerId) {
      if (ownerId == appState.currentProfile!.id) return appState.currentProfile!.name;
      final match = appState.familyMembers.where((m) => m.id == ownerId);
      return match.isEmpty ? '' : match.first.name;
    }

    final rows = <_PetRow>[];
    final chartSeries = <ChartSeries>[];
    for (final pet in pets.where((p) => selected.contains(p.id))) {
      final full = _entriesCache[pet.id] ?? const <PetWeightEntry>[]; // DESC
      final filteredAsc = <PetWeightEntry>[];
      for (var i = 0; i < full.length; i++) {
        final e = full[i];
        if (!_withinFilter(e.date)) continue;
        final previousWeightKg = _previousWeightAt(full, i);
        rows.add(_PetRow(entry: e, pet: pet, deltaKg: previousWeightKg == null ? null : e.weightKg - previousWeightKg, previousWeightKg: previousWeightKg));
        filteredAsc.add(e);
      }
      if (filteredAsc.isNotEmpty) {
        chartSeries.add(ChartSeries(
          label: pet.name,
          color: colorFor(pet.id!),
          // WeightLineChart only ever reads .date/.weightKg off each entry -
          // this is just a throwaway carrier so the pet's own entries (a
          // separate model/table entirely) can reuse the same chart widget
          // without it needing to know pets exist.
          entries: filteredAsc.reversed.map((e) => WeightEntry(userId: pet.ownerId, date: e.date, weightKg: e.weightKg, createdAt: e.createdAt)).toList(),
        ));
      }
    }
    rows.sort((a, b) {
      final byDate = b.entry.date.compareTo(a.entry.date);
      return byDate != 0 ? byDate : a.pet.name.compareTo(b.pet.name);
    });

    final groups = <String, List<_PetRow>>{};
    for (final row in rows) {
      final key = _monthLabel(DateTime(row.entry.date.year, row.entry.date.month));
      groups.putIfAbsent(key, () => []).add(row);
    }

    final showOwner = selected.length > 1;
    final singlePet = selected.length == 1 ? pets.firstWhere((p) => p.id == selected.first, orElse: () => pets.first) : null;

    return Scaffold(
      appBar: AppBar(title: Text(singlePet?.name ?? 'Pets')),
      floatingActionButton: singlePet == null || singlePet.ownerId != appState.currentProfile!.id
          ? null
          : FloatingActionButton(onPressed: () => _addEntry(singlePet, appState), child: const Icon(Icons.add_rounded)),
      body: pets.isEmpty
          ? Center(
              child: Text('Nenhum pet cadastrado ainda', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pets.length > 1) ...[
                    _PetPicker(pets: pets, selected: selected, colorFor: colorFor, ownerNameFor: ownerNameFor, onToggle: _togglePet),
                    const SizedBox(height: 12),
                  ],
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  PeriodFilter(selected: _filterDays, onChanged: (v) => setState(() => _filterDays = v)),
                  const SizedBox(height: 14),
                  SumaCard(child: WeightLineChart(series: chartSeries, unitPref: unitPref)),
                  const SizedBox(height: 14),
                  if (selected.length == 1 && rows.isNotEmpty) _PetSummaryRow(entries: rows.map((r) => r.entry).toList(), unitPref: unitPref),
                  const SizedBox(height: 18),
                  for (final entry in groups.entries) ...[
                    SectionLabel(entry.key),
                    for (final row in entry.value)
                      _PetHistoryTile(
                        row: row,
                        unitPref: unitPref,
                        showOwner: showOwner,
                        ownerName: ownerNameFor(row.pet.ownerId),
                        ownerColor: colorFor(row.pet.id!),
                        canEdit: row.pet.ownerId == appState.currentProfile!.id,
                        onEdit: () async {
                          final saved = await PetEntryFormSheet.show(context, petId: row.pet.id!, petName: row.pet.name, unitPref: unitPref, existing: row.entry);
                          if (saved == true) {
                            _entriesCache.remove(row.pet.id);
                            await _ensureLoaded(row.pet.id!);
                          }
                        },
                        onDelete: () => _confirmDelete(row.entry, row.pet),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PetPicker extends StatelessWidget {
  final List<Pet> pets;
  final Set<String> selected;
  final Color Function(String id) colorFor;
  final String Function(String ownerId) ownerNameFor;
  final ValueChanged<String> onToggle;

  const _PetPicker({required this.pets, required this.selected, required this.colorFor, required this.ownerNameFor, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final pet in pets) ...[
            _PetChip(pet: pet, color: colorFor(pet.id!), ownerName: ownerNameFor(pet.ownerId), selected: selected.contains(pet.id), onTap: () => onToggle(pet.id!)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Same glass-pill recipe as [PeriodChip]/Histórico's own member chip, with
/// a paw icon standing in for a photo and a small owner-name tag (a pet has
/// no account of its own, so "de quem é" needs spelling out - relevant
/// whenever more than one family member's pets show up in the same list).
class _PetChip extends StatelessWidget {
  final Pet pet;
  final Color color;
  final String ownerName;
  final bool selected;
  final VoidCallback onTap;
  const _PetChip({required this.pet, required this.color, required this.ownerName, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? color.withValues(alpha: 0.6) : scheme.outlineVariant.withValues(alpha: 0.5))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 12, backgroundColor: color.withValues(alpha: 0.16), child: Icon(Icons.pets_rounded, size: 13, color: color)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pet.name, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : scheme.onSurface)),
                  if (ownerName.isNotEmpty) Text('de $ownerName', style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetSummaryRow extends StatelessWidget {
  final List<PetWeightEntry> entries; // DESC
  final String unitPref;
  const _PetSummaryRow({required this.entries, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final values = entries.map((e) => e.weightKg).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final newest = entries.first;
    final oldest = entries.last;
    final periodDeltaKg = newest.weightKg - oldest.weightKg;

    String signed(double kg) {
      final v = Units.displayValue(kg, unitPref);
      final prefix = v > 0.05 ? '+' : '';
      return '$prefix${v.toStringAsFixed(1)} ${Units.label(unitPref)}';
    }

    final tiles = <Widget>[
      StatTile(icon: Icons.show_chart_rounded, color: Theme.of(context).colorScheme.primary, label: 'Média', value: Units.formatWithUnit(avg, unitPref)),
      StatTile(icon: Icons.arrow_downward_rounded, color: AppColors.positive, label: 'Mínimo', value: Units.formatWithUnit(min, unitPref)),
      StatTile(icon: Icons.arrow_upward_rounded, color: AppColors.negative, label: 'Máximo', value: Units.formatWithUnit(max, unitPref)),
      StatTile(icon: Icons.numbers_rounded, color: AppColors.hydrationAccent, label: 'Registros', value: '${entries.length}'),
      if (entries.length > 1)
        StatTile(
          icon: periodDeltaKg <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: Theme.of(context).colorScheme.primary,
          label: 'Nesse período',
          value: signed(periodDeltaKg),
        ),
    ];
    return StatGrid(desktopColumns: tiles.length, children: tiles);
  }
}

class _PetHistoryTile extends StatelessWidget {
  final _PetRow row;
  final String unitPref;
  final bool showOwner;
  final String ownerName;
  final Color ownerColor;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PetHistoryTile({
    required this.row,
    required this.unitPref,
    required this.showOwner,
    required this.ownerName,
    required this.ownerColor,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = row.entry;
    final deltaKg = row.deltaKg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SumaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: canEdit ? onEdit : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ownerColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.pets_rounded, color: ownerColor, size: 20),
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
                        _DeltaPill(deltaKg: deltaKg, unitPref: unitPref),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      DateFormat('dd/MM/yyyy').format(entry.date),
                      if (showOwner) 'de $ownerName',
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
            if (canEdit)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
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
}

class _DeltaPill extends StatelessWidget {
  final double deltaKg;
  final String unitPref;
  const _DeltaPill({required this.deltaKg, required this.unitPref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (deltaKg == 0) {
      return Pill(text: '0 ${Units.label(unitPref)}', color: scheme.outline, icon: Icons.trending_flat_rounded);
    }
    final losing = deltaKg < 0;
    final sign = losing ? '-' : '+';
    return Pill(
      text: '$sign${Units.displayValue(deltaKg.abs(), unitPref).toStringAsFixed(1)} ${Units.label(unitPref)}',
      color: scheme.onSurfaceVariant,
      icon: losing ? Icons.trending_down_rounded : Icons.trending_up_rounded,
    );
  }
}
