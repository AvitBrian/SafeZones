import 'dart:async';
import 'dart:math';
import 'package:custom_info_window/custom_info_window.dart';
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
import '../services/osm_service.dart';
import '../services/weather_service.dart';

class MapProvider with ChangeNotifier {
  final PlacesService _placesService = PlacesService();
  final Map<String, Zone> _flaggedZones = {};
  final Completer<GoogleMapController> _mapController = Completer();
  final FirestoreService _firestoreService = FirestoreService();
  final OsmService _osmService = OsmService();
  final WeatherService _weatherService = WeatherService();
  final _customInfoWindowController = CustomInfoWindowController();

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
  bool _firebaseDataLoaded = false;

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
    'Prediction': 'assets/avatars/prediction.png',
  };

  bool get firebaseDataLoaded => _firebaseDataLoaded;

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
    _firebaseDataLoaded = true;
    final fetchedZones = result['zones'] as List<Zone>;

    _flaggedZones.clear();
    for (var zone in fetchedZones) {
      final weatherData = await _weatherService.fetchWeather(
          zone.center.latitude, zone.center.longitude);
      _flaggedZones[zone.id] = zone.copyWith(weatherData: weatherData);
    }

    await _reclusterZones(SettingsProvider());
    print("[DEBUG] Zones loaded:");
    for (var z in _flaggedZones.values) {
      print(" -> ${z.id} from ${z.userId}");
    }
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
    final markers = <Marker>{};
    final circles = <Circle>{};

    for (var zone in _zones) {
      if (zone.userId == 'AI' && !settings.showAiPredictions) {
        continue;
      }

      if (zone.type == ZoneType.flag) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          zone.center.latitude,
          zone.center.longitude,
        );

        String avatarPath;

        // 🧠 AI markers get the prediction icon always
        if (zone.userId == 'AI') {
          avatarPath = dangerTagToAvatar['Prediction'] ??
              'assets/avatars/prediction.png';
          debugPrint("🎯 AI marker detected: ${zone.id}, using $avatarPath");
        } else {
          // User flags get contextual icons
          if (distance < settings.alertRadius) {
            avatarPath = dangerTagToAvatar['${zone.dangerTag}_Near'] ??
                'assets/avatars/default.png';
          } else {
            avatarPath = dangerTagToAvatar[zone.dangerTag] ??
                'assets/avatars/default.png';
          }
        }

        debugPrint("Using avatarPath: $avatarPath");

        final icon = await BitmapDescriptor.asset(
          const ImageConfiguration(size: Size(100, 100)),
          avatarPath,
        );

        markers.add(Marker(
          markerId: MarkerId(zone.id),
          position: zone.center,
          icon: icon,
          infoWindow: InfoWindow(
            title: zone.confidence != null
                ? 'Danger: ${zone.dangerTag}'
                : 'Danger',
            snippet: zone.confidence != null
                ? 'Confidence: ${zone.confidence}'
                : '${zone.dangerTag}',
          ),
        ));

        debugPrint("✅ Added marker for zone: ${zone.id} (${zone.userId})");
      } else {
        // Add danger zone circles
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
        if (context.mounted) {
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
        }
        _notifiedZones.add(closestZone.id);
      }
      _notifiedZoneId = closestZone.id;
    }

    _isInDangerZone = inDangerZone;
    notifyListeners();
  }

  Future<void> updateNearestFacilityDistances(Zone zone) async {
    try {
      /// Sets distance from flagged zone to nearest facilities
      final hospitalDistance = await _placesService.getDistanceToClosestPlace(
        latitude: zone.center.latitude,
        longitude: zone.center.longitude,
        types: ['hospital'],
      );

      final policeDistance = await _placesService.getDistanceToClosestPlace(
        latitude: zone.center.latitude,
        longitude: zone.center.longitude,
        types: ['police'],
      );

      // Add OSM distance calculations
      final buildingDistance = await _osmService.getDistanceToNearestBuilding(
        zone.center.latitude,
        zone.center.longitude,
      );

      ///to be used when needed
      // final roadDistance = await _osmService.getDistanceToNearestRoad(
      //   zone.center.latitude,
      //   zone.center.longitude,
      // );

      final updatedZone = Zone(
        id: zone.id,
        center: zone.center,
        type: zone.type,
        dangerTag: zone.dangerTag,
        policeDistance: policeDistance ?? 0.0,
        // Set default if null
        hospitalDistance: hospitalDistance ?? 0.0,
        // Set default if null
        buildingDistance: buildingDistance,
        // Set default if null
        radius: zone.radius,
        dangerLevel: zone.dangerLevel,
        count: zone.count,
      );

      // Update the flagged zones and zones
      if (zone.type == ZoneType.flag) {
        _flaggedZones[zone.id] = updatedZone;
      }

      final zoneIndex = _zones.indexWhere((z) => z.id == zone.id);
      if (zoneIndex != -1) {
        _zones[zoneIndex] = updatedZone;
      }

      // Update map with new zone data
      await updateMap(SettingsProvider());
      notifyListeners(); // Notify listeners to update UI
    } catch (e) {
      print('Error updating nearest facility distances: $e');
    }
  }

  Future<void> _addFlaggedZone({
    required LatLng position,
    required BitmapDescriptor icon,
    required String dangerTag,
    required BuildContext context,
  }) async {
    final authProvider = Provider.of<AuthService>(context, listen: false);
    String userId = authProvider.currentUser?.uid ?? '';

    // Fetch the distance to the nearest building
    final buildingDistance = await _osmService.getDistanceToNearestBuilding(
      position.latitude,
      position.longitude,
    );

    // Check if the distance to the building is less than 5 meters
    if (context.mounted) {
      if (buildingDistance < 20) {
        // Show a warning that the location is invalid
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: MyConstants.primaryColor,
            title: Text('Invalid Location',
                style: TextStyle(color: MyConstants.textColor)),
            content: Text(
              "The selected location is too close to a building (less than 20 meters). Please select a different location.",
              style: TextStyle(color: MyConstants.subtextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text('OK',
                    style: TextStyle(color: Colors.greenAccent)),
              ),
            ],
          ),
        );
        return; // Early exit to prevent further processing
      }
    }
    // Check if the new location is too close to any existing flagged zone (within 5 meters)
    final exists = _flaggedZones.values.any((zone) {
      final distance = _calculateDistance(
        LatLng(zone.center.latitude, zone.center.longitude),
        position,
      );
      return distance <=
          5; // If any zone exists within 5 meters, stop processing
    });

    if (context.mounted) {
      if (exists) {
        debugPrint("Zone already exists at this location!");
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                      backgroundColor: MyConstants.primaryColor,
                      title: Text('Place a flag?',
                          style: TextStyle(color: MyConstants.textColor)),
                      content: Text(" Zone already exists at this Location!",
                          style: TextStyle(color: MyConstants.subtextColor)),
                      actions: [
                        TextButton(
                          onPressed: () {
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Confirm',
                              style: TextStyle(color: Colors.greenAccent)),
                        ),
                      ],
                    )));
        return; // Early exit to prevent further processing
      }
    }

    // Proceed with normal flow if the location is valid (not too close to building or existing zone)
    double policeDistance = 0.0;
    double hospitalDistance = 0.0;
    double roadDistance = 0.0;

    try {
      final policeResult = await _placesService.getDistanceToClosestPlace(
        latitude: position.latitude,
        longitude: position.longitude,
        types: ['police'],
      );
      if (policeResult != null) policeDistance = policeResult;
      debugPrint("Police distance: $policeDistance");
    } catch (e) {
      debugPrint("Error getting police distance: $e");
    }

    try {
      final hospitalResult = await _placesService.getDistanceToClosestPlace(
        latitude: position.latitude,
        longitude: position.longitude,
        types: ['hospital'],
      );
      if (hospitalResult != null) hospitalDistance = hospitalResult;
      debugPrint("Hospital distance: $hospitalDistance");
    } catch (e) {
      debugPrint("Error getting hospital distance: $e");
    }

    try {
      final roadResult = await _osmService.getDistanceToNearestImportantRoad(
        position.latitude,
        position.longitude,
      );
      roadDistance = roadResult;
      debugPrint("Road distance: $roadDistance");
    } catch (e) {
      debugPrint("Error getting road distance: $e");
    }

    // Create the new flagged zone
    final weatherData = await _weatherService.fetchWeather(
        position.latitude, position.longitude);

    final timeOfDay = _getTimeOfDay(DateTime.now());

    final newZone = Zone(
        id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
        center: position,
        type: ZoneType.flag,
        count: 1,
        dangerTag: dangerTag,
        timeOfDay: timeOfDay,
        policeDistance: policeDistance,
        hospitalDistance: hospitalDistance,
        buildingDistance: buildingDistance,
        weatherData: weatherData,
        userId: userId);

    _flaggedZones[newZone.id] = newZone;

    debugPrint(
        "✅ SAVING TO FIRESTORE - Police: $policeDistance, Hospital: $hospitalDistance, Building: $buildingDistance");

    await _firestoreService.addFlaggedZone(position, dangerTag, userId,
        policeDistance: policeDistance,
        hospitalDistance: hospitalDistance,
        buildingDistance: buildingDistance,
        weatherData: weatherData);

    _markers.add(Marker(
      markerId: MarkerId(newZone.id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(
        title: 'Danger: $dangerTag',
        snippet:
            "Police: ${policeDistance.toStringAsFixed(0)} m, \nHospital: ${hospitalDistance.toStringAsFixed(0)} m,\nWeather: ${weatherData['weather'][0]['main']}'",
      ),
    ));

    await _reclusterZones(SettingsProvider());
    notifyListeners();
  }

  String _getTimeOfDay(DateTime dateTime) {
    /// determines time of day
    final hour = dateTime.hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
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
          title: Text('Place a flag?',
              style: TextStyle(color: MyConstants.textColor, fontSize: 25)),
          content: DropdownButtonFormField<String>(
            dropdownColor: MyConstants.secondaryColor.withValues(alpha: 0.9),
            items: dangerTypes
                .map((type) => DropdownMenuItem(
                    alignment: AlignmentDirectional.bottomStart,
                    value: type,
                    child: Text(type,
                        style: TextStyle(color: MyConstants.subtextColor))))
                .toList(),
            onChanged: isLoading
                ? null
                : (value) {
                    setState(() => selectedDangerTag = value);
                  },
            decoration: InputDecoration(
                labelText: 'Danger Type',
                labelStyle: TextStyle(color: MyConstants.subtextColor)),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color:
                          isLoading ? Colors.grey : Colors.deepOrangeAccent)),
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
                              : Colors.greenAccent)),
            ),
          ],
        ),
      ),
    );
  }

  void updateCameraPosition(CameraPosition position) {
    /// updates camera's position
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
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
      _customInfoWindowController.googleMapController = controller;
    }
  }

  // void onMapTap(LatLng location) {
  //   _customInfoWindowController.hideInfoWindow!();
  // }
  //
  // void onMapCameraMove(position) {
  //   _customInfoWindowController.onCameraMove!();
  // }

  void snoozeAlert() {
    /// Snoozes alerts
    _isWarningActive = false;
    _notifiedZones.clear();
    _notifiedZoneId = "";
    notifyListeners();
  }

  void applyCustomIconToAllMarkers(BitmapDescriptor customIcon) {
    this.customIcon = customIcon;
    final allMarkers = <Marker>{};

    for (var zone in _zones) {
      if (zone.type == ZoneType.flag) {
        if (zone.userId == 'AI') continue;

        allMarkers.add(Marker(
          markerId: MarkerId(zone.id),
          position: zone.center,
          icon: customIcon,
          infoWindow: const InfoWindow(title: "Flagged Zone"),
        ));
      }
    }

    for (var marker in _markers) {
      if (marker.markerId.value == "user_location") {
        allMarkers.add(marker);
      } else {
        // Keep existing marker icon unless it's a non-AI flag
        allMarkers.add(marker);
      }
    }

    _markers = allMarkers;
    notifyListeners();
  }
}
