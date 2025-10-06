import 'package:flutter/material.dart';

import 'dashboard/operations_dashboard_page.dart';
import 'map_view/map_view_page.dart';
import 'projects/projects_page.dart';
import 'room_plan/room_plan_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galvany Explorations',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static final List<_NavItem> _items = [
    _NavItem(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      view: const OperationsDashboardPage(),
    ),
    _NavItem(
      label: 'Map View',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      view: const MapViewPage(),
    ),
    _NavItem(
      label: 'Room Plan',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment,
      view: const RoomPlanPage(),
    ),
    _NavItem(
      label: 'Projects',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      view: const ProjectsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final _NavItem currentItem = _items[_selectedIndex];
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentItem.label),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (widget, animation) =>
            FadeTransition(opacity: animation, child: widget),
        child: currentItem.view,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          child: NavigationBar(
            height: 64,
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.9,
            ),
            indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
            selectedIndex: _selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: [
              for (final item in _items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.view,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget view;
}
