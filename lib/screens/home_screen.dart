import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'account_screen.dart';
import 'admin_users_screen.dart';
import 'tracking_screen.dart';

/// Shell shown once someone is logged in: bottom navigation between the
/// personal tracking history, the admin-only user management tab, and the
/// account tab. Non-admins simply don't get the "Usuários" destination.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().currentUser?.isAdmin ?? false;

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: 'Registros'),
      if (isAdmin)
        const NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Usuários'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Conta'),
    ];

    final pages = <Widget>[
      const TrackingScreen(),
      if (isAdmin) const AdminUsersScreen(),
      const AccountScreen(),
    ];

    final safeIndex = _index >= pages.length ? 0 : _index;

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
