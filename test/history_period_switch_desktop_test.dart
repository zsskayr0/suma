import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suma/models/entry.dart';
import 'package:suma/utils/units.dart';
import 'package:suma/widgets/suma_widgets.dart';
import 'package:suma/widgets/weight_line_chart.dart';

/// Faithfully reproduces Histórico's actual layout at a desktop-width
/// window (>=980px, unlike the default 800x600 test surface) - the chart
/// PLUS the summary StatGrid stacked underneath it, driven by real taps on
/// the period chips (not just widget swaps) - since the StatGrid's tile
/// count (and therefore its desktopColumns) changes between some windows
/// (e.g. a single-entry window drops the "Nesse período"/rate tiles).
void main() {
  testWidgets('tapping through every period chip at desktop width never throws', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime(2026, 8, 27);
    final start = DateTime(2021, 3, 18);
    final totalDays = now.difference(start).inDays;
    final all = <WeightEntry>[];
    var day = 0;
    var weight = 107.0;
    while (day <= totalDays) {
      all.add(WeightEntry(userId: 'u1', date: start.add(Duration(days: day)), weightKg: weight, createdAt: now));
      weight += (day % 7 == 0) ? 0.4 : -0.15;
      day += 30 + (day % 53);
    }
    all.add(WeightEntry(userId: 'u1', date: now.subtract(const Duration(days: 1)), weightKg: 83.0, createdAt: now));

    List<Object>? caught;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      (caught ??= []).add(details.exception);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    for (final goalWeightKg in [80.0, null]) {
      final harness = _Harness(all: all, goalWeightKg: goalWeightKg);
      await tester.pumpWidget(harness);
      await tester.pumpAndSettle();

      for (final label in ['30d', '90d', '6m', '1a', 'Tudo', '30d']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: 'missing chip "$label"');
        await tester.tap(finder);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pumpAndSettle();
      }
    }

    expect(caught, isNull, reason: 'threw while tapping through period chips at desktop width: $caught');
  });
}

class _Harness extends StatefulWidget {
  final List<WeightEntry> all;
  final double? goalWeightKg;
  const _Harness({required this.all, required this.goalWeightKg});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int? filterDays;

  List<WeightEntry> get window {
    if (filterDays == null) return widget.all;
    final cutoff = DateTime.now().subtract(Duration(days: filterDays!));
    final c = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return widget.all.where((e) => !e.date.isBefore(c)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = window; // ascending order expected by ChartSeries
    final ascending = entries.reversed.toList();
    final options = <String, int?>{'30d': 30, '90d': 90, '6m': 182, '1a': 365, 'Tudo': null};

    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final o in options.entries)
                      ChoiceChip(
                        label: Text(o.key),
                        selected: filterDays == o.value,
                        onSelected: (_) => setState(() => filterDays = o.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SumaCard(
                child: WeightLineChart(
                  series: [ChartSeries(label: 'Você', color: Colors.blue, entries: ascending)],
                  unitPref: 'kg',
                  goalWeightKg: widget.goalWeightKg,
                ),
              ),
              const SizedBox(height: 14),
              if (entries.isNotEmpty) _summary(entries),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(List<WeightEntry> entriesDesc) {
    final values = entriesDesc.map((e) => e.weightKg).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final newest = entriesDesc.first;
    final oldest = entriesDesc.last;
    final periodDeltaKg = newest.weightKg - oldest.weightKg;
    final daysSpan = newest.date.difference(oldest.date).inDays;
    final perWeek = daysSpan <= 90;
    final rate = daysSpan > 0 ? periodDeltaKg / (daysSpan / (perWeek ? 7 : 30)) : null;

    final tiles = <Widget>[
      StatTile(icon: Icons.show_chart_rounded, color: Colors.blue, label: 'Média', value: Units.formatWithUnit(avg, 'kg')),
      StatTile(icon: Icons.arrow_downward_rounded, color: Colors.green, label: 'Mínimo', value: Units.formatWithUnit(min, 'kg')),
      StatTile(icon: Icons.arrow_upward_rounded, color: Colors.red, label: 'Máximo', value: Units.formatWithUnit(max, 'kg')),
      StatTile(icon: Icons.numbers_rounded, color: Colors.orange, label: 'Registros', value: '${entriesDesc.length}'),
      if (entriesDesc.length > 1) ...[
        StatTile(icon: Icons.trending_down_rounded, color: Colors.blue, label: 'Nesse período', value: '${periodDeltaKg.toStringAsFixed(1)} kg'),
        if (rate != null) StatTile(icon: Icons.speed_rounded, color: Colors.blue, label: perWeek ? 'Média por semana' : 'Média por mês', value: '${rate.toStringAsFixed(1)} kg'),
      ],
    ];
    return StatGrid(desktopColumns: tiles.length, children: tiles);
  }
}
