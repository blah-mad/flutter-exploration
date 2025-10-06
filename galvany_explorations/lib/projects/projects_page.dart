import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map_view/map_location.dart';
import '../map_view/map_location_repository.dart';
import '../room_plan/room_capture_record.dart';
import '../room_plan/room_plan_repository.dart';
import '../shared/date_formatter.dart';
import 'project.dart';
import 'project_repository.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final ProjectRepository _repository = ProjectRepository();
  final RoomPlanRepository _roomPlanRepository = RoomPlanRepository();
  final MapLocationRepository _locationRepository = MapLocationRepository();

  bool _isLoading = true;
  bool _isMutating = false;
  List<Project> _projects = <Project>[];
  Map<String, RoomCaptureRecord> _roomCaptures = <String, RoomCaptureRecord>{};
  Map<String, MapLocation> _locations = <String, MapLocation>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final List<Project> projects = await _repository.loadProjects();
    final List<RoomCaptureRecord> captures =
        await _roomPlanRepository.loadRecords();
    final List<MapLocation> locations =
        await _locationRepository.loadLocations();

    if (!mounted) {
      return;
    }

    setState(() {
      _projects = projects;
      _roomCaptures = {
        for (final RoomCaptureRecord record in captures) record.id: record,
      };
      _locations = {
        for (final MapLocation location in locations) location.id: location,
      };
      _isLoading = false;
    });
  }

  Future<void> _handleCreateProject() async {
    final Project? newProject = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return ProjectEditorSheet(
          roomCaptures: _roomCaptures.values.toList(growable: false),
          mapLocations: _locations.values.toList(growable: false),
        );
      },
    );

    if (newProject == null) {
      return;
    }

    await _persistProject(newProject);
    if (mounted) {
      _showSnackbar('Project created');
    }
  }

  Future<void> _handleEditProject(Project project) async {
    final Project? updatedProject = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return ProjectEditorSheet(
          initialProject: project,
          roomCaptures: _roomCaptures.values.toList(growable: false),
          mapLocations: _locations.values.toList(growable: false),
        );
      },
    );

    if (updatedProject == null) {
      return;
    }

    await _persistProject(updatedProject);
    if (mounted) {
      _showSnackbar('Project updated');
    }
  }

  Future<void> _persistProject(Project project) async {
    setState(() => _isMutating = true);
    await _repository.upsertProject(project);
    await _loadData(showSpinner: false);
    if (mounted) {
      setState(() => _isMutating = false);
    }
  }

  Future<void> _handleDeleteProject(Project project) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove project?'),
          content: Text('Delete "${project.name}" and all notes?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isMutating = true);
    await _repository.deleteProject(project.id);
    await _loadData(showSpinner: false);
    if (mounted) {
      setState(() => _isMutating = false);
      _showSnackbar('Project removed');
    }
  }

  Future<void> _toggleTask(Project project, ProjectTask task, bool isDone) async {
    final List<ProjectTask> updatedTasks = project.tasks
        .map((ProjectTask existing) => existing.id == task.id
            ? existing.copyWith(isDone: isDone)
            : existing)
        .toList(growable: false);

    final Project updatedProject = project.copyWith(
      tasks: updatedTasks,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persistProject(updatedProject);
    if (mounted) {
      _showSnackbar(isDone ? 'Task closed' : 'Task reopened');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isBusy = _isMutating;

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Project Pipeline',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _projects.isEmpty
                              ? 'Bring survey work, maps and room scans together.'
                              : 'Track ${_projects.length} active projects and next steps.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isLoading || isBusy ? null : _handleCreateProject,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('New Project'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _projects.isEmpty
                      ? _EmptyProjectsState(
                          onCreatePressed: _handleCreateProject,
                          hasRoomCaptures: _roomCaptures.isNotEmpty,
                          hasLocations: _locations.isNotEmpty,
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadData(showSpinner: false),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: _projects.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final Project project = _projects[index];
                              return _ProjectCard(
                                project: project,
                                roomCaptures: _roomCaptures,
                                locations: _locations,
                                onEdit: () => _handleEditProject(project),
                                onDelete: () => _handleDeleteProject(project),
                                onToggleTask: (ProjectTask task, bool value) =>
                                    _toggleTask(project, task, value),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
        if (isBusy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Syncing project…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.roomCaptures,
    required this.locations,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleTask,
  });

  final Project project;
  final Map<String, RoomCaptureRecord> roomCaptures;
  final Map<String, MapLocation> locations;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(ProjectTask task, bool value) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<RoomCaptureRecord> captureList = project.roomCaptureIds
        .map((String id) => roomCaptures[id])
        .whereType<RoomCaptureRecord>()
        .toList(growable: false);
    final List<MapLocation> locationList = project.locationIds
        .map((String id) => locations[id])
        .whereType<MapLocation>()
        .toList(growable: false);
    final int completedTasks =
        project.tasks.where((ProjectTask task) => task.isDone).length;
    final double progress = project.tasks.isNotEmpty
        ? completedTasks / project.tasks.length
        : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        project.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.siteAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (project.contactName != null ||
                          project.contactPhone != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.account_circle_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  [
                                    if (project.contactName != null)
                                      project.contactName!,
                                    if (project.contactPhone != null)
                                      project.contactPhone!,
                                  ].join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (project.plannedSurvey != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.schedule, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Site survey: ${formatShortDate(project.plannedSurvey!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _StatusChip(status: project.status),
                    PopupMenuButton<_ProjectCardAction>(
                      tooltip: 'Project actions',
                      onSelected: (action) {
                        switch (action) {
                          case _ProjectCardAction.edit:
                            onEdit();
                            break;
                          case _ProjectCardAction.delete:
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return const <PopupMenuEntry<_ProjectCardAction>>[
                          PopupMenuItem<_ProjectCardAction>(
                            value: _ProjectCardAction.edit,
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit project'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          PopupMenuItem<_ProjectCardAction>(
                            value: _ProjectCardAction.delete,
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete project'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (project.notes != null && project.notes!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  project.notes!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (captureList.isNotEmpty || locationList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Linked assets',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final RoomCaptureRecord record in captureList)
                          _AttachmentChip(
                            icon: Icons.chair_alt_outlined,
                            label: record.displayName,
                          ),
                        for (final MapLocation location in locationList)
                          _AttachmentChip(
                            icon: Icons.place_outlined,
                            label: location.name,
                            tooltip: location.coordinateLabel,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (project.tasks.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Action items',
                        style: theme.textTheme.labelLarge,
                      ),
                      if (project.tasks.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: SizedBox(
                            width: 80,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                              child: LinearProgressIndicator(
                                value: progress.isNaN ? 0 : progress,
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ),
                      if (project.tasks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${math.max(0, completedTasks)}/${project.tasks.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...project.tasks.map(
                    (ProjectTask task) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: task.isDone,
                      onChanged: (bool? value) =>
                          onToggleTask(task, value ?? false),
                      title: Text(task.title),
                      subtitle: task.dueDate != null
                          ? Text(
                              'Due ${formatShortDate(task.dueDate!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Updated ${formatRelative(project.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProjectCardAction { edit, delete }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;

    switch (status) {
      case ProjectStatus.discovery:
        background = colorScheme.secondaryContainer;
        foreground = colorScheme.onSecondaryContainer;
        break;
      case ProjectStatus.surveyScheduled:
        background = colorScheme.tertiaryContainer;
        foreground = colorScheme.onTertiaryContainer;
        break;
      case ProjectStatus.installation:
        background = colorScheme.primaryContainer;
        foreground = colorScheme.onPrimaryContainer;
        break;
      case ProjectStatus.commissioning:
        background = colorScheme.surfaceContainerHighest;
        foreground = colorScheme.onSurface;
        break;
      case ProjectStatus.completed:
        background = colorScheme.inversePrimary.withValues(alpha: 0.18);
        foreground = colorScheme.primary;
        break;
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(status.icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.icon,
    required this.label,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return chip;
    }
    return Tooltip(message: tooltip!, child: chip);
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState({
    required this.onCreatePressed,
    required this.hasRoomCaptures,
    required this.hasLocations,
  });

  final VoidCallback onCreatePressed;
  final bool hasRoomCaptures;
  final bool hasLocations;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.work_outline, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Start your first project',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasRoomCaptures || hasLocations
                  ? 'Link room scans and site pins to coordinate survey work.'
                  : 'Capture a room or drop a map pin, then create your first project.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New Project'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectEditorSheet extends StatefulWidget {
  const ProjectEditorSheet({
    super.key,
    this.initialProject,
    required this.roomCaptures,
    required this.mapLocations,
  });

  final Project? initialProject;
  final List<RoomCaptureRecord> roomCaptures;
  final List<MapLocation> mapLocations;

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _notesController;
  late ProjectStatus _status;
  late DateTime? _plannedSurvey;
  late List<String> _selectedRoomCaptureIds;
  late List<String> _selectedLocationIds;
  late List<ProjectTask> _tasks;
  final TextEditingController _newTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final Project? initial = widget.initialProject;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _addressController =
        TextEditingController(text: initial?.siteAddress ?? '');
    _contactNameController =
        TextEditingController(text: initial?.contactName ?? '');
    _contactPhoneController =
        TextEditingController(text: initial?.contactPhone ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _status = initial?.status ?? ProjectStatus.discovery;
    _plannedSurvey = initial?.plannedSurvey;
    _selectedRoomCaptureIds =
        List<String>.from(initial?.roomCaptureIds ?? <String>[]);
    _selectedLocationIds =
        List<String>.from(initial?.locationIds ?? <String>[]);
    _tasks = List<ProjectTask>.from(initial?.tasks ?? <ProjectTask>[]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    _newTaskController.dispose();
    super.dispose();
  }

  void _addTask() {
    final String text = _newTaskController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _tasks = <ProjectTask>[
        ..._tasks,
        ProjectTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: text,
          isDone: false,
        ),
      ];
      _newTaskController.clear();
    });
  }

  void _removeTask(ProjectTask task) {
    setState(() {
      _tasks = _tasks.where((ProjectTask t) => t.id != task.id).toList();
    });
  }

  Future<void> _pickSurveyDate() async {
    final DateTime initialDate = _plannedSurvey ?? DateTime.now();
    final DateTime firstDate = DateTime.now().subtract(const Duration(days: 365));
    final DateTime lastDate = DateTime.now().add(const Duration(days: 365 * 3));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _plannedSurvey = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _clearSurveyDate() {
    setState(() => _plannedSurvey = null);
  }

  void _toggleRoomCapture(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedRoomCaptureIds = <String>{
          ..._selectedRoomCaptureIds,
          id,
        }.toList();
      } else {
        _selectedRoomCaptureIds = _selectedRoomCaptureIds
            .where((String existing) => existing != id)
            .toList();
      }
    });
  }

  void _toggleLocation(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedLocationIds = <String>{
          ..._selectedLocationIds,
          id,
        }.toList();
      } else {
        _selectedLocationIds = _selectedLocationIds
            .where((String existing) => existing != id)
            .toList();
      }
    });
  }

  void _save() {
    final String name = _nameController.text.trim();
    final String address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and address are required.')),
      );
      return;
    }

    final Project? initial = widget.initialProject;
    final DateTime now = DateTime.now().toUtc();
    final Project project = Project(
      id: initial?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      status: _status,
      siteAddress: address,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
      contactName: _contactNameController.text.trim().isEmpty
          ? null
          : _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim().isEmpty
          ? null
          : _contactPhoneController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      plannedSurvey: _plannedSurvey,
      roomCaptureIds: _selectedRoomCaptureIds,
      locationIds: _selectedLocationIds,
      tasks: _tasks,
    );

    Navigator.of(context).pop(project);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Material(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.initialProject == null
                            ? 'New Project'
                            : 'Edit Project',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Project name',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Site address',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownMenu<ProjectStatus>(
                        initialSelection: _status,
                        label: const Text('Status'),
                        leadingIcon: const Icon(Icons.flag_outlined),
                        dropdownMenuEntries: ProjectStatus.values
                            .map(
                              (ProjectStatus status) => DropdownMenuEntry<ProjectStatus>(
                                value: status,
                                label: status.label,
                                leadingIcon: Icon(status.icon),
                              ),
                            )
                            .toList(),
                        onSelected: (ProjectStatus? value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Survey visit', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _pickSurveyDate,
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              _plannedSurvey == null
                                  ? 'Select date'
                                  : formatShortDate(_plannedSurvey!),
                            ),
                          ),
                          if (_plannedSurvey != null)
                            TextButton(
                              onPressed: _clearSurveyDate,
                              child: const Text('Clear date'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactNameController,
                  decoration: const InputDecoration(
                    labelText: 'Site contact',
                    prefixIcon: Icon(Icons.account_circle_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Internal notes',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 24),
                _buildAttachmentSection(
                  title: 'Room scans',
                  emptyLabel: widget.roomCaptures.isEmpty
                      ? 'Capture rooms to link them here.'
                      : 'Select saved scans to link.',
                  children: widget.roomCaptures
                      .map(
                        (RoomCaptureRecord record) => FilterChip(
                          label: Text(record.displayName),
                          selected: _selectedRoomCaptureIds.contains(record.id),
                          onSelected: (bool selected) =>
                              _toggleRoomCapture(record.id, selected),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                _buildAttachmentSection(
                  title: 'Map pins',
                  emptyLabel: widget.mapLocations.isEmpty
                      ? 'Save a map pin to link the location here.'
                      : 'Select saved locations to link.',
                  children: widget.mapLocations
                      .map(
                        (MapLocation location) => FilterChip(
                          label: Text(location.name),
                          avatar: const Icon(Icons.place_outlined),
                          selected: _selectedLocationIds.contains(location.id),
                          onSelected: (bool selected) =>
                              _toggleLocation(location.id, selected),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Action items',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newTaskController,
                  decoration: InputDecoration(
                    labelText: 'Add task',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_task_outlined),
                      tooltip: 'Add task',
                      onPressed: _addTask,
                    ),
                  ),
                  onSubmitted: (_) => _addTask(),
                ),
                const SizedBox(height: 12),
                if (_tasks.isEmpty)
                  Text(
                    'No tasks yet. Add reminders for survey or installation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Column(
                    children: _tasks
                        .map(
                          (ProjectTask task) => Dismissible(
                            key: ValueKey(task.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              color: theme.colorScheme.errorContainer,
                              child: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                            onDismissed: (_) => _removeTask(task),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: task.isDone,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              onChanged: (bool? value) {
                                setState(() {
                                  _tasks = _tasks
                                      .map(
                                        (ProjectTask existing) => existing.id == task.id
                                            ? existing.copyWith(
                                                isDone: value ?? false,
                                              )
                                            : existing,
                                      )
                                      .toList();
                                });
                              },
                              title: Text(task.title),
                              subtitle: task.dueDate != null
                                  ? Text('Due ${formatShortDate(task.dueDate!)}')
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(widget.initialProject == null
                      ? 'Create project'
                      : 'Save changes'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentSection({
    required String title,
    required String emptyLabel,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Text(
                emptyLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children,
              ),
          ],
        ),
      ),
    );
  }
}
