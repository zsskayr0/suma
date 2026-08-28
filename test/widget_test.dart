import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suma/main.dart';

void main() {
  testWidgets('Suma boots and shows a loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const SumaApp(
      initialThemePref: 'system',
      initialHeightUnitPref: 'cm',
      initialNotifEnabled: false,
      initialNotifDays: {1, 2, 3, 4, 5, 6, 7},
      initialNotifHour: 8,
      initialNotifMinute: 0,
    ));

    // Before the database finishes bootstrapping, we show a spinner rather
    // than crash or render a blank screen.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
