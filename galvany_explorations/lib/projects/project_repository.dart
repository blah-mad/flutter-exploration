import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'project.dart';

class ProjectRepository {
  ProjectRepository({Directory? overrideDirectory})
    : _overrideDirectory = overrideDirectory;

  final Directory? _overrideDirectory;

  Future<List<Project>> loadProjects() async {
    final File manifest = await _manifestFile();

    if (!await manifest.exists()) {
      final List<Project> seeded = _seedProjects();
      await _writeProjects(seeded);
      return seeded;
    }

    try {
      final String raw = await manifest.readAsString();
      if (raw.trim().isEmpty) {
        return <Project>[];
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<Project> projects = decoded
          .whereType<Map<String, dynamic>>()
          .map(Project.fromJson)
          .toList();
      projects.sort((Project a, Project b) =>
          b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (_) {
      return <Project>[];
    }
  }

  Future<Project> upsertProject(Project project) async {
    final List<Project> projects = await loadProjects();
    final List<Project> updated = List<Project>.from(projects)
      ..removeWhere((Project existing) => existing.id == project.id)
      ..add(project)
      ..sort((Project a, Project b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeProjects(updated);
    return project;
  }

  Future<void> deleteProject(String id) async {
    final List<Project> projects = await loadProjects();
    final List<Project> updated = List<Project>.from(projects)
      ..removeWhere((Project project) => project.id == id);
    await _writeProjects(updated);
  }

  Future<void> _writeProjects(List<Project> projects) async {
    final File manifest = await _manifestFile();
    final List<Map<String, dynamic>> payload = projects
        .map((Project project) => project.toJson())
        .toList(growable: false);
    await manifest.writeAsString(jsonEncode(payload));
  }

  Future<File> _manifestFile() async {
    final Directory directory = await _ensureBaseDirectory();
    return File(p.join(directory.path, 'projects.json'));
  }

  Future<Directory> _ensureBaseDirectory() async {
    final Directory? override = _overrideDirectory;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }

    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory projectDir = Directory(
      p.join(documentsDir.path, 'projects'),
    );
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return projectDir;
  }

  List<Project> _seedProjects() {
    final DateTime now = DateTime.now().toUtc();
    return <Project>[
      Project(
        id: '${now.millisecondsSinceEpoch}-discovery',
        name: 'Multi-family Retrofit - Prenzlauer Berg',
        status: ProjectStatus.discovery,
        siteAddress: 'Pappelallee 18, 10437 Berlin',
        contactName: 'Leonie Müller',
        contactPhone: '+49 152 152 33',
        notes:
            'Two heat pumps proposed for south courtyard. Awaiting roof access clearance from landlord.',
        plannedSurvey: now.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 1)),
        tasks: <ProjectTask>[
          ProjectTask(
            id: '${now.microsecondsSinceEpoch}-call',
            title: 'Confirm tenant availability for survey',
            isDone: false,
            dueDate: now.add(const Duration(days: 2)),
          ),
        ],
      ),
      Project(
        id: '${now.millisecondsSinceEpoch}-installation',
        name: 'Townhouse Installation - Grunewald',
        status: ProjectStatus.installation,
        siteAddress: 'Brahmsstraße 4, 14193 Berlin',
        contactName: 'Patrick Hofmann',
        contactPhone: '+49 171 999 117',
        notes:
            'Awaiting delivery of buffer tank. Basement ceiling height checked and documented.',
        plannedSurvey: now.subtract(const Duration(days: 14)),
        createdAt: now.subtract(const Duration(days: 26)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        tasks: <ProjectTask>[
          ProjectTask(
            id: '${now.microsecondsSinceEpoch}-install',
            title: 'Mount indoor hydrobox',
            isDone: true,
          ),
          ProjectTask(
            id: '${now.microsecondsSinceEpoch}-commission',
            title: 'Schedule electrician for final hookup',
            isDone: false,
            dueDate: now.add(const Duration(days: 3)),
          ),
        ],
      ),
      Project(
        id: '${now.millisecondsSinceEpoch}-completed',
        name: 'Office Retrofit - Kreuzberg',
        status: ProjectStatus.completed,
        siteAddress: 'Maybachufer 30, 12047 Berlin',
        contactName: 'Fiona Richter',
        contactPhone: '+49 30 222 333',
        notes:
            'System commissioned last week. Collect post-install feedback during next check-in.',
        plannedSurvey: now.subtract(const Duration(days: 45)),
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }
}
