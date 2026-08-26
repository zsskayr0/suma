import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/responsive.dart';
import 'admin_users_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Shell shown once someone is logged in. On phone-width windows this is a
/// classic bottom [NavigationBar]; on desktop-width windows (Windows build)
/// it switches to a persistent side [NavigationRail] so the much larger
/// canvas gets used instead of a stretched-out phone layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().currentUser?.isAdmin ?? false;

    final items = <_NavItem>[
      _NavItem('Hoje', Icons.today_outlined, Icons.today_rounded, DashboardScreen(onViewHistory: () => _goTo(1))),
      _NavItem('Histórico', Icons.history_rounded, Icons.history_rounded, const HistoryScreen()),
      if (isAdmin) _NavItem('Usuários', Icons.group_outlined, Icons.group_rounded, const AdminUsersScreen()),
      _NavItem('Ajustes', Icons.settings_outlined, Icons.settings_rounded, const SettingsScreen()),
    ];

    final safeIndex = _index >= items.length ? 0 : _index;
    final pages = IndexedStack(index: safeIndex, children: [for (final i in items) i.page]);

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: safeIndex,
              onDestinationSelected: _goTo,
              labelType: NavigationRailLabelType.all,
              leading: const _RailBrand(),
              backgroundColor: Theme.of(context).colorScheme.surface,
              destinations: [
                for (final i in items)
                  NavigationRailDestination(icon: Icon(i.icon), selectedIcon: Icon(i.selectedIcon), label: Text(i.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _goTo,
        destinations: [
          for (final i in items) NavigationDestination(icon: Icon(i.icon), selectedIcon: Icon(i.selectedIcon), label: i.label),
        ],
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.monitor_weight_rounded, color: Theme.of(context).colorScheme.primary, size: 30),
          const SizedBox(height: 6),
          Text('Suma', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _NavItem(this.label, this.icon, this.selectedIcon, this.page);
}
