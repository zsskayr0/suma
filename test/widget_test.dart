import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:suma/config/supabase_config.dart';
import 'package:suma/main.dart';

void main() {
  // AppState's constructor resolves `Supabase.instance.client` eagerly (see
  // app_state.dart), so SumaApp can't even be built without this - the real
  // main() does the same call before runApp(). This doesn't hit the network
  // (no widget here waits on a session/query), it just satisfies the
  // package's internal "was initialize() called" assertion. Supabase.initialize
  // itself reads/writes SharedPreferences (to restore a persisted session),
  // which needs both a live binding and mocked plugin channel to work in a
  // test - shared_preferences has no real platform implementation here.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  });

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
