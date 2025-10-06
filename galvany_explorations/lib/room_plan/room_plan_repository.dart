import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'room_capture_record.dart';

class RoomPlanRepository {
  RoomPlanRepository({Directory? overrideDirectory})
    : _overrideDirectory = overrideDirectory;

  final Directory? _overrideDirectory;

  Future<Directory> _ensureBaseDirectory() async {
    final Directory? override = _overrideDirectory;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }

    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final Directory roomPlanDir = Directory(
      p.join(documentsDir.path, 'room_plans'),
    );
    if (!await roomPlanDir.exists()) {
      await roomPlanDir.create(recursive: true);
    }
    return roomPlanDir;
  }

  Future<File> _manifestFile() async {
    final Directory baseDir = await _ensureBaseDirectory();
    return File(p.join(baseDir.path, 'manifest.json'));
  }

  Future<List<RoomCaptureRecord>> loadRecords() async {
    final File manifest = await _manifestFile();
    if (!await manifest.exists()) {
      return <RoomCaptureRecord>[];
    }

    try {
      final String content = await manifest.readAsString();
      if (content.trim().isEmpty) {
        return <RoomCaptureRecord>[];
      }

      final List<dynamic> decoded = jsonDecode(content) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RoomCaptureRecord.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <RoomCaptureRecord>[];
    }
  }

  Future<void> _writeRecords(List<RoomCaptureRecord> records) async {
    final File manifest = await _manifestFile();
    final List<Map<String, dynamic>> payload = records
        .map((record) => record.toJson())
        .toList(growable: false);
    await manifest.writeAsString(jsonEncode(payload));
  }

  Future<RoomCaptureRecord?> addCapture({
    String? usdzPath,
    String? jsonPath,
  }) async {
    if ((usdzPath == null || usdzPath.isEmpty) &&
        (jsonPath == null || jsonPath.isEmpty)) {
      return null;
    }

    final Directory baseDir = await _ensureBaseDirectory();
    final DateTime now = DateTime.now().toUtc();
    final String id = now.millisecondsSinceEpoch.toString();
    final Directory captureDir = Directory(p.join(baseDir.path, id));
    if (!await captureDir.exists()) {
      await captureDir.create(recursive: true);
    }

    final String? savedUsdz = await _copyIntoDirectory(usdzPath, captureDir);
    final String? savedJson = await _copyIntoDirectory(jsonPath, captureDir);

    if (savedUsdz == null && savedJson == null) {
      if (await captureDir.exists()) {
        await captureDir.delete(recursive: true);
      }
      return null;
    }

    final RoomCaptureRecord record = RoomCaptureRecord(
      id: id,
      displayName: 'Room Capture ${_formatForDisplay(now.toLocal())}',
      createdAt: now,
      usdzPath: savedUsdz,
      jsonPath: savedJson,
    );

    final List<RoomCaptureRecord> records = await loadRecords();
    records
      ..removeWhere((existing) => existing.id == record.id)
      ..add(record)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeRecords(records);
    return record;
  }

  Future<void> deleteRecord(RoomCaptureRecord record) async {
    final Directory baseDir = await _ensureBaseDirectory();
    final Directory captureDir = Directory(p.join(baseDir.path, record.id));
    if (await captureDir.exists()) {
      await captureDir.delete(recursive: true);
    }

    final List<RoomCaptureRecord> records = await loadRecords();
    records.removeWhere((existing) => existing.id == record.id);
    await _writeRecords(records);
  }

  Future<String?> _copyIntoDirectory(
    String? sourcePath,
    Directory targetDir,
  ) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final String fileName = p.basename(sourceFile.path);
    final File destination = File(p.join(targetDir.path, fileName));

    try {
      await sourceFile.copy(destination.path);
      return destination.path;
    } catch (_) {
      return null;
    }
  }

  String _formatForDisplay(DateTime timestamp) {
    final String year = timestamp.year.toString();
    final String month = timestamp.month.toString().padLeft(2, '0');
    final String day = timestamp.day.toString().padLeft(2, '0');
    final String hour = timestamp.hour.toString().padLeft(2, '0');
    final String minute = timestamp.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
