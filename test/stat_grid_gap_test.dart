import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suma/widgets/suma_widgets.dart';

/// Regression guard for a "big blank gap after the stat grid" report: on a
/// phone-narrow width, StatGrid should size itself to exactly its two rows
/// (columns=2 for 4 tiles) with nothing unaccounted-for between it and
/// whatever comes right after it.
void main() {
  testWidgets('no unaccounted-for gap between StatGrid and the next widget', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final statGridKey = GlobalKey();
    final labelKey = GlobalKey();
    const spacerHeight = 18.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatGrid(
                  key: statGridKey,
                  children: const [
                    StatTile(icon: Icons.show_chart_rounded, color: Colors.blue, label: 'Média', value: '107.3 kg'),
                    StatTile(icon: Icons.arrow_downward_rounded, color: Colors.green, label: 'Mínimo', value: '83.0 kg'),
                    StatTile(icon: Icons.arrow_upward_rounded, color: Colors.red, label: 'Máximo', value: '134.3 kg'),
                    StatTile(icon: Icons.numbers_rounded, color: Colors.indigo, label: 'Registros', value: '54'),
                  ],
                ),
                const SizedBox(height: spacerHeight),
                SectionLabel('AGOSTO DE 2026', key: labelKey),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridBottom = tester.getBottomLeft(find.byKey(statGridKey)).dy;
    final labelTop = tester.getTopLeft(find.byKey(labelKey)).dy;

    expect(labelTop - gridBottom, spacerHeight);
  });
}
