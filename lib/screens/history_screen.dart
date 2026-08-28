import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/goal_trend.dart';
import '../utils/responsive.dart';
import '../utils/units.dart';
import '../widgets/period_filter.dart';
import '../widgets/suma_glass_sheet.dart';
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
  // Bumped by HomeScreen each time this tab becomes active again - see
  // DashboardScreen.revealToken for why.
  final Object revealToken;

  const HistoryScreen({super.key, required this.revealToken});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _filterDays;
  Set<String>? _selectedUserIds; // null until initState knows "self"
  final Map<String, List<WeightEntry>> _othersEntries = {};
  bool _loadingOthers = false;

  final _scrollCtrl = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _selectedUserIds = {appState.currentProfile!.id};
    // Picks up members who joined/left since this session started - there's
    // no realtime subscription, so a fresh look each time this tab opens is
    // the next best thing.
    appState.refreshFamilyMembers();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 400;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrollToTop() {
    return _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
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
      // The "+" to register a weight is universal now - the floating pill
      // nav's raised center button (mobile) / the rail's button (desktop) -
      // so there's no FAB here anymore.
      body: !hasAnyData
          ? Center(
              child: Text('Nenhum registro ainda', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : Stack(
              children: [
                ResponsiveBody(
                  controller: _scrollCtrl,
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
                      PeriodFilter(selected: _filterDays, onChanged: (v) => setState(() => _filterDays = v)),
                      const SizedBox(height: 14),
                      SumaCard(
                        child: WeightLineChart(series: chartSeries, unitPref: unitPref, revealToken: widget.revealToken),
                      ),
                      const SizedBox(height: 14),
                      if (selected.length == 1 && rows.isNotEmpty)
                        _SummaryRow(
                          entries: rows.map((r) => r.entry).toList(),
                          unitPref: unitPref,
                          // The goal of whoever is actually selected (an
                          // admin viewing one other member sees that
                          // member's own goal, not their own).
                          goalWeightKg: pickable.firstWhere((p) => p.id == selected.first).goalWeightKg,
                          goalType: pickable.firstWhere((p) => p.id == selected.first).goalType,
                          revealToken: widget.revealToken,
                        ),
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
                Positioned(
                  right: 16,
                  // Clears the floating bottom nav's pill + raised "+" on
                  // mobile; desktop has no floating nav, so a plain small
                  // margin is enough there.
                  bottom: Responsive.isDesktop(context) ? 20 : 96,
                  child: IgnorePointer(
                    ignoring: !_showBackToTop,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      offset: _showBackToTop ? Offset.zero : const Offset(0, 0.6),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _showBackToTop ? 1 : 0,
                        child: _BackToTopButton(onTap: _scrollToTop),
                      ),
                    ),
                  ),
                ),
              ],
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
            _MemberChip(member: member, color: colorFor(member.id), selected: selected.contains(member.id), onTap: () => onToggle(member.id)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Same flat-glass-pill recipe as [_PeriodChip], but showing the person's
/// own photo and just their first name instead of a plain text label - the
/// full name/colored-dot FilterChip felt out of place next to the period
/// selector's glass pills.
class _MemberChip extends StatelessWidget {
  final Profile member;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _MemberChip({required this.member, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.16) : (dark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: selected ? color.withValues(alpha: 0.6) : scheme.outlineVariant.withValues(alpha: dark ? 0.3 : 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.6),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? color : Colors.transparent, width: 1.6)),
                    child: UserAvatar(avatarUrl: member.avatarUrl, name: member.name, radius: 11),
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? color : scheme.onSurfaceVariant),
                    child: Text(member.firstName),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<WeightEntry> entries; // DESC
  final String unitPref;
  final double? goalWeightKg;
  final String goalType;
  final Object revealToken;
  const _SummaryRow({required this.entries, required this.unitPref, required this.goalWeightKg, required this.goalType, required this.revealToken});

  @override
  Widget build(BuildContext context) {
    final values = entries.map((e) => e.weightKg).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // "Nesse período" and the per-week/per-month rate below need at least
    // two points spanning some real time - a single entry has nothing to
    // compare against.
    final newest = entries.first;
    final oldest = entries.last;
    final periodDeltaKg = newest.weightKg - oldest.weightKg;
    final daysSpan = newest.date.difference(oldest.date).inDays;
    final periodTrend = entries.length > 1 ? goalTrendPositive(fromKg: oldest.weightKg, toKg: newest.weightKg, goalWeightKg: goalWeightKg, goalType: goalType) : null;
    // Short spans (up to ~3 months, whether that's a preset chip or a
    // custom picked date) read naturally as a weekly pace; longer ones are
    // long enough that a monthly pace is the more useful number.
    final perWeek = daysSpan <= 90;
    final rate = daysSpan > 0 ? periodDeltaKg / (daysSpan / (perWeek ? 7 : 30)) : null;

    String signed(double kg) {
      final v = Units.displayValue(kg, unitPref);
      final prefix = v > 0.05 ? '+' : ''; // toStringAsFixed already carries the "-" for negatives
      return '$prefix${v.toStringAsFixed(1)} ${Units.label(unitPref)}';
    }

    final tiles = <Widget>[
      StatTile(icon: Icons.show_chart_rounded, color: Theme.of(context).colorScheme.primary, label: 'Média', value: Units.formatWithUnit(avg, unitPref)),
      StatTile(icon: Icons.arrow_downward_rounded, color: AppColors.positive, label: 'Mínimo', value: Units.formatWithUnit(min, unitPref)),
      StatTile(icon: Icons.arrow_upward_rounded, color: AppColors.negative, label: 'Máximo', value: Units.formatWithUnit(max, unitPref)),
      StatTile(icon: Icons.numbers_rounded, color: AppColors.hydrationAccent, label: 'Registros', value: '${entries.length}'),
      if (entries.length > 1) ...[
        StatTile(
          icon: periodDeltaKg <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: Theme.of(context).colorScheme.primary,
          label: 'Nesse período',
          value: signed(periodDeltaKg),
          trendPositive: periodTrend,
        ),
        if (rate != null)
          StatTile(
            icon: Icons.speed_rounded,
            color: Theme.of(context).colorScheme.primary,
            label: perWeek ? 'Média por semana' : 'Média por mês',
            value: signed(rate),
            trendPositive: periodTrend,
          ),
      ],
    ];

    // All tiles fit on one line on desktop instead of wrapping to a second
    // row - there's easily enough width once the content column is as wide
    // as it gets there.
    return KeyedSubtree(key: ValueKey('stats_$revealToken'), child: StatGrid(desktopColumns: tiles.length, children: tiles));
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
              child: Icon(Icons.monitor_weight, color: showOwner ? ownerColor : scheme.primary, size: 20),
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
              'O registro de ${DateFormat('dd/MM/yyyy').format(entry.date)} será removido permanentemente.',
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
      await appState.deleteEntry(entry.id!);
    }
  }
}

/// Small floating button, appears once the list is scrolled past a
/// threshold - Histórico can get long (years of entries), so this beats
/// scrolling all the way back up by hand.
class _BackToTopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToTopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).cardTheme.color ?? scheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Icon(Icons.arrow_upward_rounded, color: scheme.primary, size: 20),
        ),
      ),
    );
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
