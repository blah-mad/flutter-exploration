import 'package:flutter/material.dart';

enum ProjectStatus {
  discovery,
  surveyScheduled,
  installation,
  commissioning,
  completed,
}

extension ProjectStatusDisplay on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.discovery:
        return 'Discovery';
      case ProjectStatus.surveyScheduled:
        return 'Survey Scheduled';
      case ProjectStatus.installation:
        return 'Installation';
      case ProjectStatus.commissioning:
        return 'Commissioning';
      case ProjectStatus.completed:
        return 'Completed';
    }
  }

  IconData get icon {
    switch (this) {
      case ProjectStatus.discovery:
        return Icons.lightbulb_outline;
      case ProjectStatus.surveyScheduled:
        return Icons.event_available;
      case ProjectStatus.installation:
        return Icons.bolt;
      case ProjectStatus.commissioning:
        return Icons.verified_outlined;
      case ProjectStatus.completed:
        return Icons.check_circle_outline;
    }
  }
}

class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate,
  });

  final String id;
  final String title;
  final bool isDone;
  final DateTime? dueDate;

  ProjectTask copyWith({
    String? id,
    String? title,
    bool? isDone,
    DateTime? dueDate,
  }) {
    return ProjectTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'isDone': isDone,
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  static ProjectTask fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.siteAddress,
    required this.createdAt,
    required this.updatedAt,
    this.contactName,
    this.contactPhone,
    this.notes,
    this.plannedSurvey,
    this.roomCaptureIds = const <String>[],
    this.locationIds = const <String>[],
    this.tasks = const <ProjectTask>[],
  });

  final String id;
  final String name;
  final ProjectStatus status;
  final String siteAddress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? contactName;
  final String? contactPhone;
  final String? notes;
  final DateTime? plannedSurvey;
  final List<String> roomCaptureIds;
  final List<String> locationIds;
  final List<ProjectTask> tasks;

  bool get hasRoomCaptures => roomCaptureIds.isNotEmpty;
  bool get hasLocations => locationIds.isNotEmpty;
  bool get hasTasks => tasks.isNotEmpty;

  Project copyWith({
    String? id,
    String? name,
    ProjectStatus? status,
    String? siteAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contactName,
    String? contactPhone,
    String? notes,
    DateTime? plannedSurvey,
    List<String>? roomCaptureIds,
    List<String>? locationIds,
    List<ProjectTask>? tasks,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      siteAddress: siteAddress ?? this.siteAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      plannedSurvey: plannedSurvey ?? this.plannedSurvey,
      roomCaptureIds: roomCaptureIds ?? this.roomCaptureIds,
      locationIds: locationIds ?? this.locationIds,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'status': status.name,
      'siteAddress': siteAddress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'contactName': contactName,
      'contactPhone': contactPhone,
      'notes': notes,
      'plannedSurvey': plannedSurvey?.toIso8601String(),
      'roomCaptureIds': roomCaptureIds,
      'locationIds': locationIds,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }

  static Project fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      status: ProjectStatus.values.firstWhere(
        (ProjectStatus status) => status.name == json['status'],
        orElse: () => ProjectStatus.discovery,
      ),
      siteAddress: json['siteAddress'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      contactName: json['contactName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      notes: json['notes'] as String?,
      plannedSurvey: json['plannedSurvey'] != null
          ? DateTime.tryParse(json['plannedSurvey'] as String)
          : null,
      roomCaptureIds: (json['roomCaptureIds'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      locationIds: (json['locationIds'] as List<dynamic>? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      tasks: (json['tasks'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ProjectTask.fromJson)
          .toList(),
    );
  }
}
