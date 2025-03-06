import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:safezones/providers/settings_provider.dart';
import '../services/places_service.dart';
import '../utils/constants.dart';
import '../widgets/warning.dart';
import 'package:safezones/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapProvider with ChangeNotifier {
  final PlacesService _placesService = PlacesService();
  final Map<String, Zone> _flaggedZones = {};
  final Completer<GoogleMapController> _mapController = Completer();
  final FirestoreService _firestoreService = FirestoreService();
  
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  List<Zone> _zones = [];
  Set<String> _notifiedZones = {};
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  BitmapDescriptor? customIcon;
  CameraPosition? _currentCameraPosition;
  String _notifiedZoneId = "";
  bool _isLoading = true;
  bool _isWarningActive = false;
  bool _isInDangerZone = false;
  DocumentSnapshot? _lastFetchedDocument;

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

  Future<void> checkLocationPermissions(SettingsProvider settings, BuildContext context) async {
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

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _currentPosition = position;
      await _loadZones(LatLng(position.latitude, position.longitude));
      _isLoading = false;
      
      if (_positionSubscription != null) {
        await _positionSubscription!.cancel();
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1),
      ).listen((position) {
        _currentPosition = position;
        if (settings.soundAlertsEnabled) {
        _checkProximityToDangerZones(position, settings, context);
        } else if (_isWarningActive) {
          snoozeAlert();
        }
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadZones(LatLng userLocation) async {
    final result = await _firestoreService.fetchFlaggedZones(userLocation, 5);
    final fetchedZones = result['zones'] as List<Zone>;
    
    _flaggedZones.clear();
    for (var zone in fetchedZones) {
      _flaggedZones[zone.id] = zone;
    }
    
    _reclusterZones();
  }

  void _reclusterZones() {
    final flaggedLocations = _flaggedZones.values.map((zone) => zone.center).toList();
    final clusters = <Zone>[];
    
    for (var i = 0; i < flaggedLocations.length; i++) {
      final nearbyFlags = <Zone>[];
      
      for (var zone in _flaggedZones.values) {
        if (_calculateDistance(flaggedLocations[i], zone.center) <= 300) {
          nearbyFlags.add(zone);
        }
      }
      
      if (nearbyFlags.length > 1) {
        clusters.add(Zone.dangerZone(
          'danger_${DateTime.now().millisecondsSinceEpoch}_$i',
          _calculateCenter(nearbyFlags.map((z) => z.center).toList()),
          nearbyFlags
        ));
      }
    }

    _zones = [..._flaggedZones.values, ...clusters];
    _updateMap();
  }

  void _updateMap() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    for (var zone in _zones) {
      if (zone.type == ZoneType.flag) {
        markers.add(Marker(
          markerId: MarkerId(zone.id),
          position: zone.center,
          icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Danger: ${zone.dangerTag}',
            snippet: 'Police: ${zone.policeDistance?.toStringAsFixed(0)}m, Hospital: ${zone.hospitalDistance?.toStringAsFixed(0)}m',
          ),
        ));
      } else {
        circles.add(Circle(
          circleId: CircleId(zone.id),
          center: zone.center,
          radius: zone.radius,
          fillColor: Colors.redAccent.withAlpha((zone.dangerLevel * 255).round()),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ));
      }
    }

    _markers = markers;
    _circles = circles;
    notifyListeners();
  }

  void _checkProximityToDangerZones(Position position, SettingsProvider settings, BuildContext context) {
    bool inDangerZone = false;
    Zone? closestZone;
    double closestDistance = double.infinity;
    _reclusterZones();

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

    if (closestZone != null && closestDistance <= (closestZone.radius + settings.alertRadius)) {
      if (!_notifiedZones.contains(closestZone.id)) {
        if (settings.soundAlertsEnabled && !_isWarningActive) {
          NotificationManager.show(
            context,
            message: "You are near a danger zone!",
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

    // Create new zone with updated distances
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

    // Update the zone in our maps
    if (zone.type == ZoneType.flag) {
      _flaggedZones[zone.id] = updatedZone;
    }
    
    final zoneIndex = _zones.indexWhere((z) => z.id == zone.id);
    if (zoneIndex != -1) {
      _zones[zoneIndex] = updatedZone;
    }

    _updateMap();
    notifyListeners();
  }

  Future<void> _addFlaggedZone({
    required LatLng position,
    required BitmapDescriptor icon,
    required String dangerTag,
  }) async {
    final exists = _flaggedZones.values.any((zone) {
      final distance = _calculateDistance(
        LatLng(zone.center.latitude, zone.center.longitude),
        position,
      );
      return distance <= 5;
    });

    if (exists) {
      print("Zone already exists at this location!");
      return;
    }

    // Calculate distances to the nearest hospital and police station
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

    // Create a new Zone object
    final newZone = Zone(
      id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
      center: position,
      radius: 0, // Not needed for flagged zones
      dangerLevel: 0, // Not needed for flagged zones
      type: ZoneType.flag,
      count: 1,
      dangerTag: dangerTag,
      policeDistance: policeDistance,
      hospitalDistance: hospitalDistance,
    );

    // Add the new zone to the local state
    _flaggedZones[newZone.id] = newZone;

    // Send the flagged zone to Firestore
    await _firestoreService.addFlaggedZone(position, dangerTag);

    // Optionally, update the markers on the map
    _markers.add(Marker(
      markerId: MarkerId(newZone.id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(
        title: 'Danger: $dangerTag',
        snippet: 'Police: ${policeDistance?.toStringAsFixed(0)} m, Hospital: ${hospitalDistance?.toStringAsFixed(0)} m',
      ),
    ));

    // Recluster zones and notify listeners
    _reclusterZones();
    notifyListeners();
  }

  Future<void> handleMapLongPress(LatLng position, BuildContext context, {BitmapDescriptor? icon}) async {
    if (_calculateDistance(position, LatLng(_currentPosition!.latitude, _currentPosition!.longitude)) > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can only flag zones within 1km of your location'))
      );
      return;
    }

    String? selectedDangerTag;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MyConstants.primaryColor,
        title: Text('Flag Danger Zone', style: TextStyle(color: MyConstants.secondaryColor)),
        content: DropdownButtonFormField<String>(
          dropdownColor: MyConstants.primaryColor,
          items: dangerTypes.map((type) => 
            DropdownMenuItem(value: type, child: Text(type, style: TextStyle(color: MyConstants.secondaryColor)))
          ).toList(),
          onChanged: (value) => selectedDangerTag = value,
          decoration: InputDecoration(
            labelText: 'Danger Type',
            labelStyle: TextStyle(color: MyConstants.secondaryColor)
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: MyConstants.secondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              if (selectedDangerTag != null) {
                await _addFlaggedZone(
                  position: position,
                  icon: icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  dangerTag: selectedDangerTag!,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Confirm', style: TextStyle(color: MyConstants.secondaryColor)),
          ),
        ],
      ),
    );
  }

  void updateCameraPosition(CameraPosition position) {
    _currentCameraPosition = position;
  }

  Future<void> centerOnUser() async {
    if (_currentPosition == null || !_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        18,
      ),
    );
  }

  Future<void> centerOnZone(Zone zone, ZoneType zonetype) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    if (zonetype == ZoneType.flag) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(zone.center, 25),
      );
    } else {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(zone.center, 20),
      );
    }
  }

  void setMapController(GoogleMapController controller) {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
  }

  void snoozeAlert() {
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

  LatLng _calculateCenter(List<LatLng> points) {
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    );
  }
}
