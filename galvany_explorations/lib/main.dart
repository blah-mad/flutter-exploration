import 'package:flutter/material.dart';

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
      label: 'Map View',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      view: const _PlaceholderView(
        key: ValueKey('mapView'),
        title: 'Map View',
        description:
            'Soon you\'ll be able to explore locations on an interactive map.',
        icon: Icons.map,
      ),
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
      view: const _PlaceholderView(
        key: ValueKey('projects'),
        title: 'Projects',
        description:
            'Track ongoing projects and milestones from this screen soon.',
        icon: Icons.work,
      ),
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

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
