import 'package:flutter/material.dart';

import '../map_view/map_location.dart';
import '../map_view/map_location_repository.dart';
import '../projects/project.dart';
import '../projects/project_repository.dart';
import '../room_plan/room_capture_record.dart';
import '../room_plan/room_plan_repository.dart';
import '../shared/date_formatter.dart';

class OperationsDashboardPage extends StatefulWidget {
  const OperationsDashboardPage({super.key});

  @override
  State<OperationsDashboardPage> createState() =>
      _OperationsDashboardPageState();
}

class _OperationsDashboardPageState extends State<OperationsDashboardPage> {
  final ProjectRepository _projectRepository = ProjectRepository();
  final RoomPlanRepository _roomPlanRepository = RoomPlanRepository();
  final MapLocationRepository _locationRepository = MapLocationRepository();

  bool _isLoading = true;
  List<Project> _projects = <Project>[];
  List<RoomCaptureRecord> _captures = <RoomCaptureRecord>[];
  List<MapLocation> _locations = <MapLocation>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final List<Project> projects = await _projectRepository.loadProjects();
    final List<RoomCaptureRecord> captures =
        await _roomPlanRepository.loadRecords();
    final List<MapLocation> locations =
        await _locationRepository.loadLocations();

    if (!mounted) {
      return;
    }

    setState(() {
      _projects = projects;
      _captures = captures;
      _locations = locations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final int activeProjects =
        _projects.where((Project project) => project.status != ProjectStatus.completed).length;
    final int completedThisMonth = _projects
        .where(
          (Project project) =>
              project.status == ProjectStatus.completed &&
              DateTime.now().difference(project.updatedAt).inDays <= 30,
        )
        .length;
    final int openTasks = _projects
        .expand((Project project) => project.tasks)
        .where((ProjectTask task) => !task.isDone)
        .length;
    final List<Project> upcomingVisits = _projects
        .where((Project project) =>
            project.plannedSurvey != null &&
            project.plannedSurvey!.isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort((Project a, Project b) =>
          a.plannedSurvey!.compareTo(b.plannedSurvey!));
    final List<Project> recentlyUpdated = List<Project>.from(_projects)
      ..sort((Project a, Project b) => b.updatedAt.compareTo(a.updatedAt));

    final Map<ProjectStatus, int> statusCounts = <ProjectStatus, int>{
      for (final ProjectStatus status in ProjectStatus.values) status: 0,
    };
    for (final Project project in _projects) {
      statusCounts[project.status] = (statusCounts[project.status] ?? 0) + 1;
    }

    final List<_OpenTask> taskQueue = _projects
        .expand(
          (Project project) => project.tasks
              .where((ProjectTask task) => !task.isDone)
              .map((ProjectTask task) => _OpenTask(project: project, task: task)),
        )
        .toList()
      ..sort((a, b) {
        final DateTime? dueA = a.task.dueDate;
        final DateTime? dueB = b.task.dueDate;
        if (dueA == null && dueB == null) {
          return a.project.name.compareTo(b.project.name);
        }
        if (dueA == null) {
          return 1;
        }
        if (dueB == null) {
          return -1;
        }
        return dueA.compareTo(dueB);
      });

    return RefreshIndicator(
      onRefresh: () => _refresh(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: <Widget>[
          Text(
            'Operations Radar',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _projects.isEmpty
                ? 'Create a project to kick things off.'
                : 'Stay ahead of surveys, installs and commissioning milestones.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _MetricTile(
                title: 'Active projects',
                value: activeProjects.toString(),
                icon: Icons.work_outline,
                color: colorScheme.primary,
              ),
              _MetricTile(
                title: 'Open tasks',
                value: openTasks.toString(),
                icon: Icons.checklist_outlined,
                color: colorScheme.tertiary,
              ),
              _MetricTile(
                title: 'Room scans',
                value: _captures.length.toString(),
                icon: Icons.chair_alt_outlined,
                color: colorScheme.secondary,
              ),
              _MetricTile(
                title: 'Site pins',
                value: _locations.length.toString(),
                icon: Icons.place_outlined,
                color: colorScheme.error,
              ),
              _MetricTile(
                title: 'Closed (30d)',
                value: completedThisMonth.toString(),
                icon: Icons.verified_outlined,
                color: colorScheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_projects.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Status mix',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        for (final ProjectStatus status in ProjectStatus.values)
                          if ((statusCounts[status] ?? 0) > 0)
                            _StatusIndicatorChip(
                              status: status,
                              count: statusCounts[status] ?? 0,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (upcomingVisits.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Upcoming site visits',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final Project project in upcomingVisits.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: Text(project.name),
                        subtitle: Text(
                          'Survey ${formatShortDate(project.plannedSurvey!)} • ${project.siteAddress}',
                        ),
                      ),
                    if (upcomingVisits.length > 3)
                      Text(
                        '+ ${upcomingVisits.length - 3} more scheduled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (taskQueue.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Next actions',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final _OpenTask item in taskQueue.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_arrow_outlined),
                        title: Text(item.task.title),
                        subtitle: Text(
                          '${item.project.name}${item.task.dueDate != null ? ' • Due ${formatShortDate(item.task.dueDate!)}' : ''}',
                        ),
                      ),
                    if (taskQueue.length > 4)
                      Text(
                        '+ ${taskQueue.length - 4} more open tasks',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (recentlyUpdated.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Recently updated',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final Project project in recentlyUpdated.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(project.status.icon),
                        title: Text(project.name),
                        subtitle: Text(
                          '${project.status.label} • ${formatRelative(project.updatedAt)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_projects.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.lightbulb_outline,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Link captured rooms and site pins to projects so the field team always lands with context.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicatorChip extends StatelessWidget {
  const _StatusIndicatorChip({required this.status, required this.count});

  final ProjectStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(status.icon),
      label: Text('${status.label} • $count'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _OpenTask {
  const _OpenTask({required this.project, required this.task});

  final Project project;
  final ProjectTask task;
}
