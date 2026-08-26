import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/app_intro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  runApp(const SumaApp());
}

class SumaApp extends StatelessWidget {
  const SumaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      // Selector instead of Consumer: AppState.notifyListeners() fires on
      // nearly every interaction (entry edits, optimistic pref updates,
      // family refreshes), and MaterialApp is an expensive thing to rebuild
      // (it re-evaluates the whole navigator/theme setup). Scoping this to
      // just the one field that actually needs to reach MaterialApp - the
      // theme preference - means those other, far more frequent notifies
      // only re-run the (cheap) screens that actually watch AppState
      // themselves, instead of also rebuilding MaterialApp every time.
      child: Selector<AppState, String?>(
        selector: (_, appState) => appState.currentProfile?.themePref,
        builder: (context, themePref, _) {
          return MaterialApp(
            title: 'Suma',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeModeFor(themePref),
            home: const _RootRouter(),
          );
        },
      ),
    );
  }

  ThemeMode _themeModeFor(String? pref) {
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
