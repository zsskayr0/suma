import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suma/widgets/suma_glass_sheet.dart';

/// Regression test for "os menus ficam em branco" - wrapping the backdrop
/// blur's `Positioned.fill` inside a `RepaintBoundary` (instead of the
/// other way around) breaks Stack's positioning of it, and separately can
/// leave the panel content simply never appearing. This mounts a real
/// sheet and asserts its actual content (not just the barrier/blur) shows
/// up on screen.
void main() {
  testWidgets('showSumaGlassSheet actually renders its panel content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSumaGlassSheet<void>(
                  context,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Unidade de peso'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Unidade de peso'), findsOneWidget);
  });
}
