import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_roomplan/flutter_roomplan.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'room_capture_record.dart';
import 'room_plan_repository.dart';

class RoomPlanPage extends StatefulWidget {
  const RoomPlanPage({super.key});

  @override
  State<RoomPlanPage> createState() => _RoomPlanPageState();
}

class _RoomPlanPageState extends State<RoomPlanPage> {
  final FlutterRoomplan _roomplan = FlutterRoomplan();
  final RoomPlanRepository _repository = RoomPlanRepository();

  bool _isLoading = true;
  bool _isProcessingCapture = false;
  bool _isLaunchingScan = false;
  List<RoomCaptureRecord> _records = <RoomCaptureRecord>[];

  @override
  void initState() {
    super.initState();
    _roomplan.onRoomCaptureFinished(_handleCaptureFinished);
    _refreshRecords(showSpinner: true);
  }

  Future<void> _refreshRecords({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final List<RoomCaptureRecord> records = await _repository.loadRecords();
    if (!mounted) {
      return;
    }

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _handleCaptureFinished() async {
    if (!mounted) {
      return;
    }

    setState(() => _isProcessingCapture = true);

    try {
      final String? usdzPath = await _roomplan.getUsdzFilePath();
      final String? jsonPath = await _roomplan.getJsonFilePath();
      final RoomCaptureRecord? record = await _repository.addCapture(
        usdzPath: usdzPath,
        jsonPath: jsonPath,
      );

      if (!mounted) {
        return;
      }

      await _refreshRecords();

      if (record != null) {
        _showSnackbar('Room capture saved');
      } else {
        _showSnackbar('Room capture finished but nothing was exported');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackbar('Failed to store room capture: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessingCapture = false);
      }
    }
  }

  Future<void> _startRoomScan() async {
    if (_isLaunchingScan) {
      return;
    }

    setState(() => _isLaunchingScan = true);

    try {
      final bool supported = await _roomplan.isSupported();
      if (!supported) {
        if (!mounted) {
          return;
        }
        await _showUnsupportedDialog();
        return;
      }

      await _roomplan.startScan();
    } catch (error) {
      if (mounted) {
        _showSnackbar('Unable to start RoomPlan: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingScan = false);
      }
    }
  }

  Future<void> _shareRecord(RoomCaptureRecord record) async {
    final List<XFile> files = <XFile>[];

    if (record.usdzPath != null && record.usdzPath!.isNotEmpty) {
      final File usdzFile = File(record.usdzPath!);
      if (await usdzFile.exists()) {
        files.add(XFile(usdzFile.path, mimeType: 'model/vnd.usdz+zip'));
      }
    }

    if (record.jsonPath != null && record.jsonPath!.isNotEmpty) {
      final File jsonFile = File(record.jsonPath!);
      if (await jsonFile.exists()) {
        files.add(XFile(jsonFile.path, mimeType: 'application/json'));
      }
    }

    if (files.isEmpty) {
      _showSnackbar('No exported files available to share');
      return;
    }

    await Share.shareXFiles(files, text: record.displayName);
  }

  Future<void> _openRecord(
    RoomCaptureRecord record, {
    bool preferJson = false,
  }) async {
    final List<String?> candidates = <String?>[
      if (!preferJson) record.usdzPath,
      if (!preferJson) record.jsonPath,
      if (preferJson) record.jsonPath,
      if (preferJson) record.usdzPath,
    ];

    final String? pathToOpen = candidates.firstWhere(
      (String? path) => path != null && path.isNotEmpty,
      orElse: () => null,
    );

    if (pathToOpen == null) {
      _showSnackbar('No exported files found for this capture');
      return;
    }

    final File file = File(pathToOpen);
    if (!await file.exists()) {
      _showSnackbar('The exported file could not be found');
      return;
    }

    final OpenResult result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      final String message = result.message;
      if (message.isNotEmpty) {
        _showSnackbar(message);
      } else {
        _showSnackbar('Unable to open the exported file');
      }
    }
  }

  Future<void> _deleteRecord(RoomCaptureRecord record) async {
    await _repository.deleteRecord(record);
    await _refreshRecords();
    if (mounted) {
      _showSnackbar('Capture deleted');
    }
  }

  Future<void> _showUnsupportedDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('RoomPlan Not Available'),
          content: const Text(
            'This feature requires a device with a LiDAR-enabled camera running iOS 17 or newer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatSubtitle(RoomCaptureRecord record) {
    final DateTime localTime = record.createdAt.toLocal();
    final String datePart =
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';
    final String timePart =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final List<String> pieces = <String>['Captured $datePart $timePart'];
    final List<String> attachments = <String>[];
    if (record.hasUsdz) {
      attachments.add('USDZ');
    }
    if (record.hasJson) {
      attachments.add('JSON');
    }
    if (attachments.isNotEmpty) {
      pieces.add('Files: ${attachments.join(', ')}');
    }
    return pieces.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showProgressOverlay = _isProcessingCapture;

    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Saved Room Captures',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isLaunchingScan ? null : _startRoomScan,
                    icon: _isLaunchingScan
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(_isLaunchingScan ? 'Preparing…' : 'Create New'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                  ? _EmptyState(onCreatePressed: _startRoomScan)
                  : RefreshIndicator(
                      onRefresh: () => _refreshRecords(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final RoomCaptureRecord record = _records[index];
                          return Card(
                            child: _RoomCaptureTile(
                              record: record,
                              subtitle: _formatSubtitle(record),
                              onOpen: () => _openRecord(record),
                              onOpenJson: record.hasJson
                                  ? () => _openRecord(record, preferJson: true)
                                  : null,
                              onShare: () => _shareRecord(record),
                              onDelete: () => _deleteRecord(record),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
        if (showProgressOverlay)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing capture…',
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

class _RoomCaptureTile extends StatelessWidget {
  const _RoomCaptureTile({
    required this.record,
    required this.subtitle,
    required this.onOpen,
    required this.onShare,
    this.onOpenJson,
    this.onDelete,
  });

  final RoomCaptureRecord record;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback? onOpenJson;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.apartment)),
      title: Text(record.displayName),
      subtitle: Text(subtitle),
      onTap: onOpen,
      trailing: PopupMenuButton<_RoomCaptureAction>(
        onSelected: (action) {
          switch (action) {
            case _RoomCaptureAction.open:
              onOpen();
              break;
            case _RoomCaptureAction.openJson:
              onOpenJson?.call();
              break;
            case _RoomCaptureAction.share:
              onShare();
              break;
            case _RoomCaptureAction.delete:
              onDelete?.call();
              break;
          }
        },
        itemBuilder: (BuildContext context) {
          final List<PopupMenuEntry<_RoomCaptureAction>> entries =
              <PopupMenuEntry<_RoomCaptureAction>>[
                const PopupMenuItem<_RoomCaptureAction>(
                  value: _RoomCaptureAction.open,
                  child: ListTile(
                    leading: Icon(Icons.open_in_new),
                    title: Text('Open'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<_RoomCaptureAction>(
                  value: _RoomCaptureAction.share,
                  child: ListTile(
                    leading: Icon(Icons.ios_share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];

          if (onOpenJson != null) {
            entries.insert(
              1,
              const PopupMenuItem<_RoomCaptureAction>(
                value: _RoomCaptureAction.openJson,
                child: ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text('Open JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }

          if (onDelete != null) {
            entries.add(
              const PopupMenuItem<_RoomCaptureAction>(
                value: _RoomCaptureAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }

          return entries;
        },
      ),
    );
  }
}

enum _RoomCaptureAction { open, openJson, share, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.apartment_outlined,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No room captures yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap “Create New” to launch RoomPlan and scan your first space.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New'),
            ),
          ],
        ),
      ),
    );
  }
}
