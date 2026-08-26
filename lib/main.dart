import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
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
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Suma',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeModeFor(appState.currentProfile?.themePref),
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
        return const WelcomeScreen();
      case AppPhase.needsOnboarding:
        return const OnboardingScreen();
      case AppPhase.ready:
        return const HomeScreen();
    }
  }
}
