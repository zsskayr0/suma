import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suma/models/entry.dart';
import 'package:suma/widgets/suma_widgets.dart';
import 'package:suma/widgets/weight_line_chart.dart';

/// Reproduces "muda a duração do gráfico (30 dias / 90 dias / 6 meses / 1
/// ano / Tudo) e ele pisca vermelho" - mounts the chart the same way
/// Histórico does (inside a SumaCard) with a *sparse*, multi-year dataset
/// like a real account's (a handful of entries a month, not one a day), then
/// switches the plotted series to each of Histórico's period-filter windows
/// in turn - including windows that land on 0 or 1 points - pumping through
/// the ~550ms domain-zoom animation each time, and fails loudly if any
/// frame throws (FlutterError.onError), including layout-overflow errors.
void main() {
  testWidgets('switching the chart between period-filter windows never throws (sparse data)', (tester) async {
    final now = DateTime(2026, 8, 27);
    final start = DateTime(2021, 3, 18);
    final totalDays = now.difference(start).inDays;
    // ~53 entries unevenly spread across ~5.4 years, like the account in
    // the bug report - most windows this sparse land on 0 or 1 points.
    final all = <WeightEntry>[];
    var day = 0;
    var weight = 107.0;
    while (day <= totalDays) {
      all.add(WeightEntry(userId: 'u1', date: start.add(Duration(days: day)), weightKg: weight, createdAt: now));
      weight += (day % 7 == 0) ? 0.4 : -0.15;
      day += 30 + (day % 53); // irregular spacing, occasionally bunched up
    }
    if (all.last.date.isBefore(now.subtract(const Duration(days: 5)))) {
      all.add(WeightEntry(userId: 'u1', date: now.subtract(const Duration(days: 1)), weightKg: 83.0, createdAt: now));
    }

    List<Object>? caught;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      (caught ??= []).add(details.exception);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    Widget host(List<WeightEntry> entries) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SumaCard(
              child: WeightLineChart(
                series: [ChartSeries(label: 'Você', color: Colors.blue, entries: entries)],
                unitPref: 'kg',
                goalWeightKg: 80,
              ),
            ),
          ),
        ),
      );
    }

    List<WeightEntry> windowOf(int? days) {
      if (days == null) return all;
      final cutoff = now.subtract(Duration(days: days));
      return all.where((e) => !e.date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))).toList();
    }

    for (final days in [null, 30, 90, 182, 365, null, 30, 90]) {
      final window = windowOf(days);
      await tester.pumpWidget(host(window));
      // Step through the domain-zoom transition frame by frame instead of
      // pumpAndSettle, since a mid-transition frame is exactly where the
      // reported flash happened.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
    }

    expect(caught, isNull, reason: 'paint()/layout threw during a period switch: $caught');
  });
}
