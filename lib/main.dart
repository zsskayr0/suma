import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/setup_admin_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(const SumaApp());
}

class SumaApp extends StatelessWidget {
  const SumaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: 'Suma',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D6B)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D6B), brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const _RootRouter(),
      ),
    );
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
      case AppPhase.needsSetup:
        return const SetupAdminScreen();
      case AppPhase.needsLogin:
        return const LoginScreen();
      case AppPhase.ready:
        return const HomeScreen();
    }
  }
}
