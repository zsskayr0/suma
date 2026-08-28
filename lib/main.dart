import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/app_intro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  // Read before the first frame, not inside AppState.bootstrap(), so there's
  // no flash of the wrong theme while a SharedPreferences read is pending -
  // this is device-local and doesn't need the auth session to be resolved.
  final prefs = await SharedPreferences.getInstance();
  final initialThemePref = prefs.getString(themePrefStorageKey) ?? 'system';
  final initialHeightUnitPref = prefs.getString(heightUnitPrefStorageKey) ?? 'cm';

  final notifEnabled = prefs.getBool(notifEnabledStorageKey) ?? false;
  final savedDays = prefs.getString(notifDaysStorageKey);
  final notifDays = savedDays == null || savedDays.isEmpty
      ? {1, 2, 3, 4, 5, 6, 7}
      : savedDays.split(',').map(int.parse).toSet();
  final notifHour = prefs.getInt(notifHourStorageKey) ?? 8;
  final notifMinute = prefs.getInt(notifMinuteStorageKey) ?? 0;
  await NotificationService.instance.init();
  // Re-arms the schedule on every launch, not just when the settings screen
  // is opened - an app update (or reinstall) wipes Android's AlarmManager
  // state even though SharedPreferences survives it, so without this a
  // reminder someone turned on could silently stop firing after an update.
  if (notifEnabled && notifDays.isNotEmpty) {
    await NotificationService.instance.scheduleWeekly(weekdays: notifDays, hour: notifHour, minute: notifMinute);
  }

  runApp(SumaApp(
    initialThemePref: initialThemePref,
    initialHeightUnitPref: initialHeightUnitPref,
    initialNotifEnabled: notifEnabled,
    initialNotifDays: notifDays,
    initialNotifHour: notifHour,
    initialNotifMinute: notifMinute,
  ));
}

class SumaApp extends StatelessWidget {
  final String initialThemePref;
  final String initialHeightUnitPref;
  final bool initialNotifEnabled;
  final Set<int> initialNotifDays;
  final int initialNotifHour;
  final int initialNotifMinute;

  const SumaApp({
    super.key,
    required this.initialThemePref,
    required this.initialHeightUnitPref,
    required this.initialNotifEnabled,
    required this.initialNotifDays,
    required this.initialNotifHour,
    required this.initialNotifMinute,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        themePref: initialThemePref,
        heightUnitPref: initialHeightUnitPref,
        notifEnabled: initialNotifEnabled,
        notifDays: initialNotifDays,
        notifHour: initialNotifHour,
        notifMinute: initialNotifMinute,
      )..bootstrap(),
      // Selector instead of Consumer: AppState.notifyListeners() fires on
      // nearly every interaction (entry edits, optimistic pref updates,
      // family refreshes), and MaterialApp is an expensive thing to rebuild
      // (it re-evaluates the whole navigator/theme setup). Scoping this to
      // just the one field that actually needs to reach MaterialApp - the
      // theme preference - means those other, far more frequent notifies
      // only re-run the (cheap) screens that actually watch AppState
      // themselves, instead of also rebuilding MaterialApp every time.
      child: Selector<AppState, String>(
        selector: (_, appState) => appState.themePref,
        builder: (context, themePref, _) {
          final appState = context.read<AppState>();
          // Cheap on purpose - see AppState.themePreviewOverride. This
          // ValueListenableBuilder is the only thing that rebuilds while
          // the Tema sheet's live preview is flipping between options; the
          // rest of the app (and its own heavier AppState.notifyListeners()
          // fan-out) stays untouched until the choice is actually confirmed.
          return ValueListenableBuilder<String?>(
            valueListenable: appState.themePreviewOverride,
            builder: (context, preview, _) {
              return MaterialApp(
                title: 'Suma',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: _themeModeFor(preview ?? themePref),
                home: const _RootRouter(),
              );
            },
          );
        },
      ),
    );
  }

  ThemeMode _themeModeFor(String pref) {
    switch (pref) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Picks the right top-level screen for the current [AppPhase]. Individual
/// screens never need to know about the others - they just call into
/// [AppState] and this widget reacts to the resulting phase change.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<AppState>().phase;
    switch (phase) {
      case AppPhase.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppPhase.needsAuth:
        return const _PreAuthFlow();
      case AppPhase.needsOnboarding:
        return const OnboardingScreen();
      case AppPhase.ready:
        return const HomeScreen();
    }
  }
}

/// Shows the app-explainer intro once (skippable) before [WelcomeScreen] -
/// local state rather than persisted, so it reappears each time someone
/// signs all the way out, which is fine for how rarely that happens.
class _PreAuthFlow extends StatefulWidget {
  const _PreAuthFlow();

  @override
  State<_PreAuthFlow> createState() => _PreAuthFlowState();
}

class _PreAuthFlowState extends State<_PreAuthFlow> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_introDone) {
      return AppIntroScreen(onDone: () => setState(() => _introDone = true));
    }
    return const WelcomeScreen();
  }
}
