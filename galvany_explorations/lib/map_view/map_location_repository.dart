import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'map_location.dart';

class MapLocationRepository {
  MapLocationRepository({Directory? overrideDirectory})
    : _overrideDirectory = overrideDirectory;

  final Directory? _overrideDirectory;

  Future<List<MapLocation>> loadLocations() async {
    final File manifest = await _manifestFile();
    if (!await manifest.exists()) {
      return <MapLocation>[];
    }

    try {
      final String contents = await manifest.readAsString();
      if (contents.trim().isEmpty) {
        return <MapLocation>[];
      }
      final List<dynamic> decoded = jsonDecode(contents) as List<dynamic>;
      final List<MapLocation> locations = decoded
          .whereType<Map<String, dynamic>>()
          .map(MapLocation.fromJson)
          .toList();
      locations.sort((MapLocation a, MapLocation b) =>
          b.createdAt.compareTo(a.createdAt));
      return locations;
    } catch (_) {
      return <MapLocation>[];
    }
  }

  Future<MapLocation> addLocation({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final DateTime timestamp = DateTime.now().toUtc();
    final MapLocation location = MapLocation(
      id: timestamp.millisecondsSinceEpoch.toString(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: timestamp,
    );

    final List<MapLocation> locations = await loadLocations();
    final List<MapLocation> updated = List<MapLocation>.from(locations)
      ..removeWhere((MapLocation existing) => existing.id == location.id)
      ..add(location)
      ..sort((MapLocation a, MapLocation b) =>
          b.createdAt.compareTo(a.createdAt));
    await _write(updated);
    return location;
  }

  Future<void> deleteLocation(MapLocation location) async {
    final List<MapLocation> locations = await loadLocations();
    final List<MapLocation> updated = List<MapLocation>.from(locations)
      ..removeWhere((MapLocation existing) => existing.id == location.id);
    await _write(updated);
  }

  Future<void> _write(List<MapLocation> locations) async {
    final File manifest = await _manifestFile();
    final List<Map<String, dynamic>> serialized = locations
        .map((MapLocation location) => location.toJson())
        .toList(growable: false);
    await manifest.writeAsString(jsonEncode(serialized));
  }

  Future<File> _manifestFile() async {
    final Directory directory = await _ensureBaseDirectory();
    return File(p.join(directory.path, 'locations.json'));
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
    final Directory mapDir = Directory(p.join(documentsDir.path, 'map_locations'));
    if (!await mapDir.exists()) {
      await mapDir.create(recursive: true);
    }
    return mapDir;
  }
}
