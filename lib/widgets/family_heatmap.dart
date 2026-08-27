import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'suma_widgets.dart';

const _monthNames = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];
const _weekdayLetters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']; // Mon..Sun

/// Admin-only, GitHub-style contribution grid: one cell per day, colored by
/// how many family members logged a weight that day. Lives on the Usuários
/// tab, below the goal-proximity ranking - only rendered when there's more
/// than one person in the family (a single-person family has nothing to
/// compare).
class FamilyHeatmap extends StatefulWidget {
  const FamilyHeatmap({super.key});

  @override
  State<FamilyHeatmap> createState() => _FamilyHeatmapState();
}

class _FamilyHeatmapState extends State<FamilyHeatmap> {
  late Future<Map<DateTime, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().familyContributionCounts();
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = context.watch<AppState>().familyMembers.length;
    final scheme = Theme.of(context).colorScheme;

    return SumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text('Contribuições da família', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<DateTime, int>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 108, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              return _HeatGrid(counts: snap.data!, memberCount: memberCount == 0 ? 1 : memberCount);
            },
          ),
        ],
      ),
    );
  }
}

class _HeatGrid extends StatelessWidget {
  final Map<DateTime, int> counts;
  final int memberCount;
  const _HeatGrid({required this.counts, required this.memberCount});

  static const _cellSize = 12.0;
  static const _cellGap = 3.0;
  static const _days = 126;

  /// A single continuous ramp within Suma's own blue/turquoise family - pale,
  /// low-saturation cyan at low participation, up to a rich, fully-saturated
  /// deep blue at full participation. No hue jump (e.g. green -> blue)
  /// anywhere along the ramp, unlike the old green-to-blue version.
  Color _colorFor(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    if (count <= 0) return scheme.surfaceContainerHighest.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.7);
    final ratio = (count / memberCount).clamp(0.0, 1.0);
    return Color.lerp(AppColors.cyan.withValues(alpha: 0.35), AppColors.deepBlue, ratio)!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    // Align the grid so columns are Mon-Sun weeks and the last column ends
    // on this week's Sunday (or today, whichever comes first visually).
    final gridEnd = todayMidnight.add(Duration(days: (7 - todayMidnight.weekday) % 7));
    final gridStart = gridEnd.subtract(Duration(days: _days + 6));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final weekCount = (totalDays / 7).ceil();

    String? lastMonth;
    final columns = <Widget>[];
    for (var w = 0; w < weekCount; w++) {
      final weekStart = gridStart.add(Duration(days: w * 7));
      final monthLabel = _monthNames[weekStart.month - 1];
      final showMonthLabel = monthLabel != lastMonth;
      if (showMonthLabel) lastMonth = monthLabel;

      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final date = weekStart.add(Duration(days: d));
        if (date.isAfter(todayMidnight) || date.isBefore(gridStart)) {
          cells.add(const SizedBox(width: _cellSize, height: _cellSize));
        } else {
          final count = counts[date] ?? 0;
          cells.add(
            Tooltip(
              message: '${DateFormat('dd/MM/yyyy').format(date)} · $count de $memberCount registraram',
              child: Container(
                width: _cellSize,
                height: _cellSize,
                decoration: BoxDecoration(color: _colorFor(context, count), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          );
        }
        if (d != 6) cells.add(const SizedBox(height: _cellGap));
      }

      columns.add(
        Padding(
          padding: const EdgeInsets.only(right: _cellGap),
          child: Column(
            children: [
              SizedBox(
                height: 14,
                child: showMonthLabel
                    ? Text(monthLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10))
                    : null,
              ),
              const SizedBox(height: 2),
              Column(mainAxisSize: MainAxisSize.min, children: cells),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 16),
                child: Column(
                  children: [
                    for (final l in _weekdayLetters) ...[
                      SizedBox(height: _cellSize, child: Text(l, style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant))),
                      const SizedBox(height: _cellGap),
                    ],
                  ],
                ),
              ),
              ...columns,
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Menos', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            for (final c in [0, 1, 2, memberCount]) ...[
              Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: _colorFor(context, c), borderRadius: BorderRadius.circular(2.5))),
            ],
            const SizedBox(width: 6),
            Text('Mais', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
