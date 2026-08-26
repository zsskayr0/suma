import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suma/main.dart';

void main() {
  testWidgets('Suma boots and shows a loading state', (WidgetTester tester) async {
    await tester.pumpWidget(const SumaApp());

    // Before the database finishes bootstrapping, we show a spinner rather
    // than crash or render a blank screen.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
