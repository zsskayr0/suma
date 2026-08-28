import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the "Text shadow blur radius should be non-negative"
/// crash reported when tapping through Histórico's period chips: an
/// AnimatedContainer whose boxShadow toggles between a real shadow and none
/// must never animate with an overshooting curve (Curves.easeOutBack and
/// friends) - the overshoot pushes BoxShadow.lerp's blurRadius briefly
/// negative, and Flutter's Shadow assertion (shared between text shadows and
/// box shadows) rejects that mid-animation.
void main() {
  testWidgets('an AnimatedContainer toggling boxShadow null<->present never overshoots into a negative blurRadius', (tester) async {
    List<Object>? caught;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      (caught ??= []).add(details.exception);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    Widget host(bool selected) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic, // must NOT be an overshooting "back"/"elastic" curve
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? Colors.blue : Colors.grey,
                boxShadow: selected ? const [BoxShadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 3))] : null,
              ),
            ),
          ),
        ),
      );
    }

    for (final selected in [false, true, false, true]) {
      await tester.pumpWidget(host(selected));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
    }

    expect(caught, isNull, reason: 'AnimatedContainer boxShadow toggle threw: $caught');
  });
}
