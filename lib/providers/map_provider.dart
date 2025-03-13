import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:safezones/providers/settings_provider.dart';
import '../services/places_service.dart';
import '../utils/constants.dart';
import '../utils/snack_bar.dart';
import '../widgets/warning.dart';
import 'package:safezones/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:safezones/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class MapProvider with ChangeNotifier {
  final PlacesService _placesService = PlacesService();
  final Map<String, Zone> _flaggedZones = {};
  final Completer<GoogleMapController> _mapController = Completer();
  final FirestoreService _firestoreService = FirestoreService();

  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  List<Zone> _zones = [];
  final Set<String> _notifiedZones = {};
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  BitmapDescriptor? customIcon;
  CameraPosition? _currentCameraPosition;
  String _notifiedZoneId = "";
  bool _isLoading = true;
  bool _isWarningActive = false;
  bool _isInDangerZone = false;

  Map<String, String> dangerTagToAvatar = {
    'Theft': 'assets/avatars/theft.png',
    'Theft_Near': 'assets/avatars/theft_near.png',
    'Assault': 'assets/avatars/assault.png',
    'Assault_Near': 'assets/avatars/assault_near.png',
    'Accident': 'assets/avatars/accident.png',
    'Accident_Near': 'assets/avatars/accident_near.png',
    'Natural Hazard': 'assets/avatars/hazard.png',
    'Natural Hazard_Near': 'assets/avatars/hazard_near.png',
    'Other': 'assets/avatars/other.png',
    'Other_Near': 'assets/avatars/other_near.png',
  };

  Set<Circle> get circles => _circles;

  Set<Marker> get markers => _markers;

  List<Zone> get zones => _zones;

  Map<String, Zone> get flaggedZones => _flaggedZones;

  Position? get currentPosition => _currentPosition;

  CameraPosition? get currentCameraPosition => _currentCameraPosition;

  String get notifiedZoneId => _notifiedZoneId;

  bool get isLoading => _isLoading;

  bool get isWarningActive => _isWarningActive;

  bool get isInDangerZone => _isInDangerZone;

  List<String> dangerTypes = [
    'Theft',
    'Assault',
    'Accident',
    'Natural Hazard',
    'Other'
  ];

  Future<void> checkLocationPermissions(
      SettingsProvider settings, BuildContext context) async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoading = false;
        notifyListeners();
        if (context.mounted) {
          openSnackBar(
            context,
            'Location services are disabled. Please enable location',
            Colors.red,
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLoading = false;
          notifyListeners();
          if (context.mounted) {
            openSnackBar(
              context,
              'Location permissions are denied',
              Colors.red,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLoading = false;
        notifyListeners();
        if (context.mounted) {
          openSnackBar(
            context,
            'Location permissions are permanently denied, please enable in settings',
            Colors.red,
          );
        }
        return;
      }

      if (!settings.locationTracking) {
        _isLoading = false;
        if (_positionSubscription != null) {
          await _positionSubscription!.cancel();
          _positionSubscription = null;
        }
        _currentPosition = null;
        notifyListeners();
        return;
      }

      // Get initial position
      final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best)
          .timeout(
        const Duration(seconds: 10), // Increased timeout
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );

      _currentPosition = position;

      // Load zones before setting up stream
      await _loadZones(LatLng(position.latitude, position.longitude));

      // Set up position stream after initial load
      if (_positionSubscription != null) {
        await _positionSubscription!.cancel();
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).listen((position) {
        _currentPosition = position;
        if (settings.soundAlertsEnabled && context.mounted) {
          _checkProximityToDangerZones(position, settings, context);
        } else if (_isWarningActive) {
          snoozeAlert();
        }
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in checkLocationPermissions: $e');
      _isLoading = false;
      notifyListeners();

      if (context.mounted) {
        openSnackBar(
          context,
          'Error getting location: ${e.toString()}',
          Colors.red,
        );
      }
    }
  }

  Future<void> _loadZones(LatLng userLocation) async {
    /// Loads flagged and danger zones
    final result = await _firestoreService.fetchFlaggedZones(userLocation, 5);
    final fetchedZones = result['zones'] as List<Zone>;

    _flaggedZones.clear();
    for (var zone in fetchedZones) {
      _flaggedZones[zone.id] = zone;
    }

    await _reclusterZones(SettingsProvider());
  }

  Future<void> _reclusterZones(SettingsProvider settings) async {
    /// Creates dangerzone when over 5 flags are clustered.

    // Perform clustering in a compute function to avoid blocking the main thread
    await compute(_performClustering, _flaggedZones.values.toList())
        .then((clusters) {
      _zones = [..._flaggedZones.values, ...clusters];
      updateMap(settings);
    });
  }

  static List<Zone> _performClustering(List<Zone> zones) {
    final clusters = <Zone>[];
    final flaggedLocations = zones.map((zone) => zone.center).toList();

    for (var i = 0; i < flaggedLocations.length; i++) {
      final nearbyFlags = <Zone>[];

      for (var zone in zones) {
        if (_calculateDistance(flaggedLocations[i], zone.center) <= 150) {
          nearbyFlags.add(zone);
        }
      }

      if (nearbyFlags.length >= 5) {
        double maxDistance = 0;
        for (var j = 0; j < nearbyFlags.length; j++) {
          for (var k = j + 1; k < nearbyFlags.length; k++) {
            maxDistance = max(
                maxDistance,
                Zone.calculateDistance(
                    nearbyFlags[j].center, nearbyFlags[k].center));
          }
        }

        double radius = (maxDistance / 2).clamp(40.0, 500.0);

        Zone dangerZone = Zone.dangerZone(
          'danger_${DateTime.now().millisecondsSinceEpoch}_$i',
          Zone.calculateCenter(nearbyFlags.map((z) => z.center).toList()),
          nearbyFlags,
        );

        dangerZone = Zone(
          id: dangerZone.id,
          center: dangerZone.center,
          type: ZoneType.dangerZone,
          radius: radius,
          dangerLevel: dangerZone.dangerLevel,
          count: nearbyFlags.length,
        );

        for (var existingZone in clusters) {
          if (existingZone.overlapsWith(dangerZone)) {
            dangerZone = Zone.combineZones(existingZone, dangerZone);
            clusters.remove(existingZone);
            break;
          }
        }

        clusters.add(dangerZone);
      }
    }

    return clusters;
  }

  Future<void> updateMap(SettingsProvider settings) async {
    /// updates the map
    final markers = <Marker>{};
    final circles = <Circle>{};

    for (var zone in _zones) {
      if (zone.type == ZoneType.flag) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          zone.center.latitude,
          zone.center.longitude,
        );

        String avatarPath;
        if (distance < settings.alertRadius) {
          avatarPath = dangerTagToAvatar['${zone.dangerTag}_Near'] ??
              'assets/avatars/default_avatar.png';
        } else {
          avatarPath = dangerTagToAvatar[zone.dangerTag] ??
              'assets/avatars/default_avatar.png';
        }

        final icon = await BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(100, 100)),
          avatarPath,
        );

        markers.add(Marker(
          markerId: MarkerId(zone.id),
          position: zone.center,
          icon: icon,
          infoWindow: InfoWindow(
            title: 'Danger: ${zone.dangerTag}',
            snippet:
                'Police: ${zone.policeDistance?.toStringAsFixed(0)} m, Hospital: ${zone.hospitalDistance?.toStringAsFixed(0)} m',
          ),
        ));
      } else {
        circles.add(Circle(
          circleId: CircleId(zone.id),
          center: zone.center,
          radius: zone.radius,
          fillColor:
              Colors.redAccent.withAlpha((zone.dangerLevel * 255).round()),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ));
      }
    }

    _markers = markers;
    _circles = circles;
    notifyListeners();
  }

  static double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  void _checkProximityToDangerZones(Position position,
      SettingsProvider settings, BuildContext context) async {
    /// Checks the users proximity to flagged and danger zones
    bool inDangerZone = false;
    Zone? closestZone;
    double closestDistance = double.infinity;
    await _reclusterZones(settings);

    for (var zone in _zones) {
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance < closestDistance) {
        closestDistance = distance;
        closestZone = zone;
      }

      if (distance < zone.radius) {
        inDangerZone = true;
      }
    }

    if (closestZone != null &&
        closestDistance <= (closestZone.radius + settings.alertRadius)) {
      if (!_notifiedZones.contains(closestZone.id)) {
        if (settings.soundAlertsEnabled && !_isWarningActive) {
          NotificationManager.show(
            context,
            message: "You are near a flagged zone!",
            color: Colors.red,
            zoneId: closestZone.id,
            onSnooze: snoozeAlert,
          );
          _isWarningActive = true;
        }
        _notifiedZones.add(closestZone.id);
      }
      _notifiedZoneId = closestZone.id;
    }

    _isInDangerZone = inDangerZone;
    notifyListeners();
  }

  Future<void> updateNearestFacilityDistances(Zone zone) async {
    /// sets distance from flagged zone to nearest policy or health facility.
    final hospitalDistance = await _placesService.getDistanceToClosestPlace(
      latitude: zone.center.latitude,
      longitude: zone.center.longitude,
      type: 'hospital',
    );

    final policeDistance = await _placesService.getDistanceToClosestPlace(
      latitude: zone.center.latitude,
      longitude: zone.center.longitude,
      type: 'police',
    );

    final updatedZone = Zone(
      id: zone.id,
      center: zone.center,
      type: zone.type,
      dangerTag: zone.dangerTag,
      policeDistance: policeDistance,
      hospitalDistance: hospitalDistance,
      radius: zone.radius,
      dangerLevel: zone.dangerLevel,
      count: zone.count,
    );

    if (zone.type == ZoneType.flag) {
      _flaggedZones[zone.id] = updatedZone;
    }

    final zoneIndex = _zones.indexWhere((z) => z.id == zone.id);
    if (zoneIndex != -1) {
      _zones[zoneIndex] = updatedZone;
    }

    await updateMap(SettingsProvider());
    notifyListeners();
  }

  Future<void> _addFlaggedZone({
    /// Adds a flagged zone to the map
    required LatLng position,
    required BitmapDescriptor icon,
    required String dangerTag,
    required BuildContext context,
  }) async {
    final authProvider = Provider.of<AuthService>(context, listen: false);
    String userId = authProvider.currentUser?.uid ?? '';

    final exists = _flaggedZones.values.any((zone) {
      final distance = _calculateDistance(
        LatLng(zone.center.latitude, zone.center.longitude),
        position,
      );
      return distance <= 5;
    });

    if (exists) {
      debugPrint("Zone already exists at this location!");
      return;
    }

    // Calculates distances to the nearest hospital and police station
    final policeDistance = await _placesService.getDistanceToClosestPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      type: 'police',
    );
    final hospitalDistance = await _placesService.getDistanceToClosestPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      type: 'hospital',
    );

    final newZone = Zone(
      id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
      center: position,
      type: ZoneType.flag,
      count: 1,
      dangerTag: dangerTag,
      policeDistance: policeDistance,
      hospitalDistance: hospitalDistance,
    );

    _flaggedZones[newZone.id] = newZone;

    await _firestoreService.addFlaggedZone(position, dangerTag, userId);

    _markers.add(Marker(
      markerId: MarkerId(newZone.id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(
        title: 'Danger: $dangerTag',
        snippet:
            'Police: ${policeDistance?.toStringAsFixed(0)} m, Hospital: ${hospitalDistance?.toStringAsFixed(0)} m',
      ),
    ));

    await _reclusterZones(SettingsProvider());
    notifyListeners();
  }

  Future<void> handleMapLongPress(LatLng position, BuildContext context,
      {BitmapDescriptor? icon}) async {
    /// handles long press on the map which triggers the flagging system
    if (_calculateDistance(position,
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude)) >
        1000) {
      openSnackBar(
        context,
        'Can only flag zones within 1km of your location',
        Colors.red,
      );
      return;
    }

    String? selectedDangerTag;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: MyConstants.primaryColor,
          title: Text('Flag Danger Zone',
              style: TextStyle(color: MyConstants.secondaryColor)),
          content: DropdownButtonFormField<String>(
            dropdownColor: MyConstants.primaryColor,
            items: dangerTypes
                .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type,
                        style: TextStyle(color: MyConstants.secondaryColor))))
                .toList(),
            onChanged: isLoading
                ? null
                : (value) {
                    setState(() => selectedDangerTag = value);
                  },
            decoration: InputDecoration(
                labelText: 'Danger Type',
                labelStyle: TextStyle(color: MyConstants.secondaryColor)),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isLoading
                          ? Colors.grey
                          : MyConstants.secondaryColor)),
            ),
            TextButton(
              onPressed: isLoading || selectedDangerTag == null
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      await _addFlaggedZone(
                        position: position,
                        icon: icon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed),
                        dangerTag: selectedDangerTag!,
                        context: context,
                      );

                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Confirm',
                      style: TextStyle(
                          color: selectedDangerTag == null
                              ? Colors.grey
                              : MyConstants.secondaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  void updateCameraPosition(CameraPosition position) {
    /// updates camers position
    _currentCameraPosition = position;
  }

  Future<void> centerOnUser() async {
    if (_currentPosition == null || !_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        20,
      ),
    );
  }

  Future<void> centerOnZone(Zone zone, ZoneType zonetype) async {
    /// Centers camera on the user.
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    if (zonetype == ZoneType.flag) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(zone.center, 20),
      );
    } else {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(zone.center, 18),
      );
    }
  }

  void setMapController(GoogleMapController controller) {
    /// sets up map controller
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
  }

  void snoozeAlert() {
    /// Snoozes alerts
    _isWarningActive = false;
    _notifiedZones.clear();
    _notifiedZoneId = "";
    notifyListeners();
  }

  void applyCustomIconToAllMarkers(BitmapDescriptor customIcon) {
    /// Applies custom icon for markers
    this.customIcon = customIcon;
    final allMarkers = <Marker>{};
    for (var zone in _zones) {
      if (zone.type == ZoneType.flag) {
        allMarkers.add(Marker(
          markerId: MarkerId(zone.id),
          position: zone.center,
          icon: customIcon,
          infoWindow: const InfoWindow(title: "Flagged Zone"),
        ));
      }
    }
    for (var marker in _markers) {
      if (marker.markerId.value == "user_location") continue;
      allMarkers.add(Marker(
        markerId: marker.markerId,
        position: marker.position,
        icon: customIcon,
        infoWindow: marker.infoWindow,
      ));
    }
    _markers = allMarkers;
    notifyListeners();
  }
}
