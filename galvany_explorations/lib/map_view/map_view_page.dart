import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_location.dart';
import 'map_location_repository.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final MapLocationRepository _repository = MapLocationRepository();

  bool _isLoading = true;
  bool _isFetchingCurrentLocation = false;
  List<MapLocation> _locations = <MapLocation>[];

  MapLocation? _activeLocation;
  Position? _activePosition;
  double? _activeDistanceMeters;
  Duration? _activeEta;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final List<MapLocation> locations = await _repository.loadLocations();
    if (!mounted) {
      return;
    }
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
  }

  Future<void> _handleAddLocation() async {
    final Position? currentPosition = await _ensureCurrentPosition(
      showErrorFeedback: false,
    );

    if (!mounted) {
      return;
    }

    final LatLng initialCenter = currentPosition != null
        ? LatLng(currentPosition.latitude, currentPosition.longitude)
        : const LatLng(41.3917, 2.1649); // Barcelona city centre fallback.

    final _AddLocationResult? result = await showModalBottomSheet<_AddLocationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return _AddLocationSheet(initialCenter: initialCenter);
      },
    );

    if (result == null) {
      return;
    }

    await _repository.addLocation(
      name: result.name,
      latitude: result.position.latitude,
      longitude: result.position.longitude,
    );

    if (!mounted) {
      return;
    }

    await _loadLocations();

    if (mounted) {
      _showSnackbar('Location saved');
    }
  }

  Future<void> _openLocation(MapLocation location) async {
    setState(() {
      _activeLocation = location;
      _activePosition = null;
      _activeDistanceMeters = null;
      _activeEta = null;
      _locationError = null;
      _isFetchingCurrentLocation = true;
    });

    final Position? position = await _ensureCurrentPosition();

    if (!mounted) {
      return;
    }

    if (position == null) {
      setState(() {
        _isFetchingCurrentLocation = false;
        _locationError = 'We couldn\'t determine your current location.';
      });
      _showSnackbar('Enable location services to view directions.');
      return;
    }

    final double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );
    const double averageWalkingSpeedMetersPerSecond = 1.4;
    final Duration eta = Duration(
      seconds: distance <= 0
          ? 0
          : (distance / averageWalkingSpeedMetersPerSecond).round(),
    );

    setState(() {
      _activePosition = position;
      _activeDistanceMeters = distance;
      _activeEta = eta;
      _isFetchingCurrentLocation = false;
    });
  }

  void _closeOverlay() {
    setState(() {
      _activeLocation = null;
      _activePosition = null;
      _activeDistanceMeters = null;
      _activeEta = null;
      _locationError = null;
      _isFetchingCurrentLocation = false;
    });
  }

  Future<void> _launchDirections(MapLocation location) async {
    final Uri destinationUri = Uri.parse(
      'http://maps.apple.com/?daddr=${location.latitude},${location.longitude}',
    );
    final bool launched = await launchUrl(
      destinationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showSnackbar('Unable to open directions on this device.');
    }
  }

  Future<void> _confirmDelete(MapLocation location) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove location?'),
          content: Text('Delete "${location.name}" from your saved places?'),
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

    await _repository.deleteLocation(location);
    await _loadLocations();

    if (mounted) {
      _showSnackbar('Location removed');
    }
  }

  Future<Position?> _ensureCurrentPosition({bool showErrorFeedback = true}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showErrorFeedback && mounted) {
        _showSnackbar('Location services are disabled.');
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (showErrorFeedback && mounted) {
        _showSnackbar(
          'Location permissions are required to show your current position.',
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (error) {
      if (showErrorFeedback && mounted) {
        _showSnackbar('Unable to retrieve current location.');
      }
      return null;
    }
  }

  String? _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) {
      return null;
    }
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String? _formatEta(Duration? duration) {
    if (duration == null) {
      return null;
    }
    if (duration.inSeconds == 0) {
      return 'Arrived';
    }
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  void _showSnackbar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
                      'Saved Locations',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _handleAddLocation,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add Location'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _locations.isEmpty
                      ? _EmptyState(onAddPressed: _handleAddLocation)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: _locations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            final MapLocation location = _locations[index];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.place_outlined),
                                ),
                                title: Text(location.name),
                                subtitle: Text(location.coordinateLabel),
                                onTap: () => _openLocation(location),
                                trailing: IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _confirmDelete(location),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        if (_activeLocation != null)
          _LocationDetailOverlay(
            location: _activeLocation!,
            userPosition: _activePosition,
            isLoadingUserPosition: _isFetchingCurrentLocation,
            distanceLabel: _formatDistance(_activeDistanceMeters),
            etaLabel: _formatEta(_activeEta),
            error: _locationError,
            onClose: _closeOverlay,
            onGetDirections: () => _launchDirections(_activeLocation!),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPressed});

  final VoidCallback onAddPressed;

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
              Icons.map_outlined,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No locations yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap “Add Location” to drop a pin on the map and save it for later.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDetailOverlay extends StatelessWidget {
  const _LocationDetailOverlay({
    required this.location,
    required this.userPosition,
    required this.isLoadingUserPosition,
    required this.distanceLabel,
    required this.etaLabel,
    required this.error,
    required this.onClose,
    required this.onGetDirections,
  });

  final MapLocation location;
  final Position? userPosition;
  final bool isLoadingUserPosition;
  final String? distanceLabel;
  final String? etaLabel;
  final String? error;
  final VoidCallback onClose;
  final VoidCallback onGetDirections;

  @override
  Widget build(BuildContext context) {
    final LatLng destination = LatLng(location.latitude, location.longitude);
    final Position? user = userPosition;
    final Set<Annotation> annotations = <Annotation>{
      Annotation(
        annotationId: AnnotationId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: location.name),
      ),
    };
    final Set<Polyline> polylines = <Polyline>{};

    LatLng initialTarget = destination;
    double initialZoom = 14;

    if (user != null) {
      final LatLng userLatLng = LatLng(user.latitude, user.longitude);
      annotations.add(
        Annotation(
          annotationId: AnnotationId('user'),
          position: userLatLng,
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );

      polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blueAccent,
          width: 4,
          points: <LatLng>[userLatLng, destination],
        ),
      );

      initialTarget = LatLng(
        (user.latitude + destination.latitude) / 2,
        (user.longitude + destination.longitude) / 2,
      );
      initialZoom = 11.5;
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                    child: AppleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialTarget,
                        zoom: initialZoom,
                      ),
                      annotations: annotations,
                      polylines: polylines,
                      compassEnabled: true,
                      myLocationEnabled: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _LocationInfoCard(
                  location: location,
                  distanceLabel: distanceLabel,
                  etaLabel: etaLabel,
                  error: error,
                  isLoading: isLoadingUserPosition,
                  onGetDirections: onGetDirections,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  const _LocationInfoCard({
    required this.location,
    required this.distanceLabel,
    required this.etaLabel,
    required this.error,
    required this.isLoading,
    required this.onGetDirections,
  });

  final MapLocation location;
  final String? distanceLabel;
  final String? etaLabel;
  final String? error;
  final bool isLoading;
  final VoidCallback onGetDirections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              location.name,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              location.coordinateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Fetching your location…'),
                ],
              )
            else if (error != null)
              Text(
                error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              )
            else
              Row(
                children: <Widget>[
                  if (distanceLabel != null)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.social_distance, size: 18),
                          const SizedBox(width: 8),
                          Text('Distance $distanceLabel'),
                        ],
                      ),
                    ),
                  if (etaLabel != null)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.schedule, size: 18),
                          const SizedBox(width: 8),
                          Text('ETA $etaLabel'),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: error == null ? onGetDirections : null,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLocationSheet extends StatefulWidget {
  const _AddLocationSheet({required this.initialCenter});

  final LatLng initialCenter;

  @override
  State<_AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends State<_AddLocationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  AppleMapController? _inlineMapController;
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialCenter;
    _syncControllersWithPosition(widget.initialCenter);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _syncControllersWithPosition(LatLng position) {
    _latitudeController.text = position.latitude.toStringAsFixed(6);
    _longitudeController.text = position.longitude.toStringAsFixed(6);
    _moveInlineMapCamera();
  }

  void _updateSelectedPositionFromFields() {
    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lon = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lon == null) {
      return;
    }
    setState(() {
      _selectedPosition = LatLng(lat, lon);
    });
    _moveInlineMapCamera();
  }

  Future<void> _openMapPicker() async {
    final LatLng fallback = _selectedPosition ?? widget.initialCenter;
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return _MapPickerPage(initialLocation: fallback);
        },
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedPosition = picked;
      _syncControllersWithPosition(picked);
    });
  }

  void _onInlineMapCreated(AppleMapController controller) {
    _inlineMapController = controller;
    _moveInlineMapCamera();
  }

  Future<void> _moveInlineMapCamera() async {
    final AppleMapController? controller = _inlineMapController;
    final LatLng? target = _selectedPosition;
    if (controller == null || target == null) {
      return;
    }
    await controller.moveCamera(
      CameraUpdate.newLatLngZoom(target, 14),
    );
  }

  bool get _canSubmit {
    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lon = double.tryParse(_longitudeController.text.trim());
    return _nameController.text.trim().isNotEmpty && lat != null && lon != null;
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final double? lat = double.tryParse(_latitudeController.text.trim());
    final double? lon = double.tryParse(_longitudeController.text.trim());

    if (name.isEmpty || lat == null || lon == null) {
      return;
    }

    Navigator.of(context).pop(
      _AddLocationResult(name: name, position: LatLng(lat, lon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LatLng? pin = _selectedPosition;
    final Set<Annotation> annotations = pin == null
        ? <Annotation>{}
        : <Annotation>{
            Annotation(
              annotationId: AnnotationId('new-location'),
              position: pin,
              infoWindow: InfoWindow(title: _nameController.text.isEmpty
                  ? 'New Location'
                  : _nameController.text.trim()),
            ),
          };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Add a Location',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Location name',
                hintText: 'e.g. Showroom entrance',
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    onChanged: (_) => _updateSelectedPositionFromFields(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    onChanged: (_) => _updateSelectedPositionFromFields(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Choose on map'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                child: Stack(
                  children: <Widget>[
                    AppleMap(
                      key: ValueKey<String>(
                        pin == null
                            ? 'initial-${widget.initialCenter.latitude}-${widget.initialCenter.longitude}'
                            : 'pin-${pin.latitude}-${pin.longitude}',
                      ),
                      initialCameraPosition: CameraPosition(
                        target: pin ?? widget.initialCenter,
                        zoom: 13,
                      ),
                      onMapCreated: _onInlineMapCreated,
                      annotations: annotations,
                      compassEnabled: true,
                      myLocationEnabled: true,
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openMapPicker,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pin == null
                  ? 'Tap the map preview to pick a spot.'
                  : 'Selected: ${pin.latitude.toStringAsFixed(5)}, '
                      '${pin.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLocationResult {
  const _AddLocationResult({required this.name, required this.position});

  final String name;
  final LatLng position;
}

class _MapPickerPage extends StatefulWidget {
  const _MapPickerPage({required this.initialLocation});

  final LatLng initialLocation;

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  late CameraPosition _cameraPosition;
  late LatLng _pickedLocation;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _cameraPosition = CameraPosition(target: widget.initialLocation, zoom: 14);
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_pickedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AppleMap(
                  initialCameraPosition: _cameraPosition,
                  compassEnabled: true,
                  myLocationEnabled: true,
                  onCameraMove: (CameraPosition position) {
                    _cameraPosition = position;
                  },
                  onCameraIdle: () {
                    setState(() {
                      _pickedLocation = _cameraPosition.target;
                    });
                  },
                ),
                IgnorePointer(
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Drag the map until the marker sits on your point of interest.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${_pickedLocation.latitude.toStringAsFixed(6)}, '
                  '${_pickedLocation.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Use this location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
