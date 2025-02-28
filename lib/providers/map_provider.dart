import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:safezones/providers/settings_provider.dart';
import '../utils/constants.dart';
import '../widgets/warning.dart';

class MapProvider with ChangeNotifier {
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isInDangerZone = false;
  StreamSubscription<Position>? _positionSubscription;
  List<Zone> _zones = [];
  Set<String> _notifiedZones = {};
  String _notifiedZoneId = "";
  String get notifiedZoneId => _notifiedZoneId;
  Completer<GoogleMapController> _mapController = Completer();
  bool _isWarningActive = false;
  bool get isWarningActive => _isWarningActive;

  Set<Circle> get circles => _circles;
  Set<Marker> get markers => _markers;
  bool get isLoading => _isLoading;
  bool get isInDangerZone => _isInDangerZone;
  List<Zone> get zones => _zones;
  Position? get currentPosition => _currentPosition;
  final Map<String, Zone> _flaggedZones = {};
  Map<String, Zone> get flaggedZones => _flaggedZones;

  Future<void> checkLocationPermissions(SettingsProvider settings, BuildContext context) async {
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _currentPosition = position;
      _isLoading = false;
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1),
      ).listen((position) {
        _currentPosition = position;
        _checkProximityToDangerZones(position, settings, context);
        notifyListeners();
      });
      _loadZones(position);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GoogleMapController> getMapController() async {
    return _mapController.future;
  }

  CameraPosition? _currentCameraPosition;
  CameraPosition? get currentCameraPosition => _currentCameraPosition;

  void updateCameraPosition(CameraPosition position) {
    _currentCameraPosition = position;
  }

  void updateZones(List<LatLng> flaggedLocations) {
    _zones = Zone.createZones(flaggedLocations);
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

  void _loadZones(Position position) {
    final baseLocation = LatLng(position.latitude, position.longitude);
    final flaggedCoordinates = _generateFlaggedCoordinates(baseLocation);
    final zones = Zone.createZones(flaggedCoordinates, clusterDistance: 300);
    _createMarkersForFlaggedCoordinates(flaggedCoordinates);
    _updateMap(zones);
    if (customIcon != null) {
      initializeMarkersWithCustomIcon(customIcon!);
    }
  }

  BitmapDescriptor? customIcon;

  void updateMarkersWithCustomIcon(BitmapDescriptor icon) {
    customIcon = icon;
    final updatedMarkers = <Marker>{};
    for (var marker in _markers) {
      updatedMarkers.add(Marker(
        markerId: marker.markerId,
        position: marker.position,
        icon: icon,
        infoWindow: marker.infoWindow,
      ));
    }
    _markers = updatedMarkers;
    notifyListeners();
  }

  void _createMarkersForFlaggedCoordinates(List<LatLng> coordinates) {
    for (var i = 0; i < coordinates.length; i++) {
      final coordinate = coordinates[i];
      final markerId = 'predefined_flagged_${i}';
      final zone = Zone(
        id: markerId,
        center: coordinate,
        radius: 0,
        dangerLevel: 0,
        type: ZoneType.flagged,
        count: 1,
      );
      _zones.add(zone);
    }
  }

  void initializeMarkersWithCustomIcon(BitmapDescriptor customIcon) {
    final newMarkers = <Marker>{};

    for (var zone in _flaggedZones.values) {
      newMarkers.add(Marker(
        markerId: MarkerId(zone.id),
        position: zone.center,
        icon: customIcon,
        infoWindow: InfoWindow(
          title: 'Danger: ${zone.dangerTag}',
          snippet: 'Lighting: ${zone.lighting}',
        ),
      ));
    }

    _markers = newMarkers;
    notifyListeners();
  }

  List<LatLng> _generateFlaggedCoordinates(LatLng baseLocation) {
    return [
      LatLng(baseLocation.latitude + 0.001, baseLocation.longitude + 0.001),
      LatLng(baseLocation.latitude + 0.0012, baseLocation.longitude + 0.0012),
      LatLng(baseLocation.latitude + 0.0013, baseLocation.longitude + 0.0011),
      LatLng(baseLocation.latitude + 0.004, baseLocation.longitude - 0.002),
      LatLng(baseLocation.latitude - 0.002, baseLocation.longitude - 0.002),
      LatLng(baseLocation.latitude - 0.0021, baseLocation.longitude - 0.0021),
      LatLng(baseLocation.latitude - 0.0022, baseLocation.longitude - 0.0023),
      LatLng(baseLocation.latitude - 0.005, baseLocation.longitude + 0.005),
      LatLng(baseLocation.latitude + 0.003, baseLocation.longitude + 0.004),
      LatLng(baseLocation.latitude + 0.0031, baseLocation.longitude + 0.0042),
      LatLng(baseLocation.latitude + 0.0032, baseLocation.longitude + 0.0041),
    ];
  }

  void _updateMap(List<Zone> zones) {
    final markers = <Marker>{};
    final circles = <Circle>{};
    for (var zone in zones.where((z) => z.type != ZoneType.flagged)) {
      circles.add(Circle(
        circleId: CircleId(zone.id),
        center: zone.center,
        radius: zone.radius,
        fillColor: Colors.redAccent.withOpacity(zone.dangerLevel),
        strokeColor: Colors.red,
        strokeWidth: 2,
      ));
    }
    for (var zone in zones.where((z) => z.type == ZoneType.flagged)) {
      markers.add(Marker(
        markerId: MarkerId(zone.id),
        position: zone.center,
        icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Flagged Zone"),
      ));
    }
    _markers = markers;
    _circles = circles;
    _zones = zones;
    notifyListeners();
  }

  void applyCustomIconToAllMarkers(BitmapDescriptor customIcon) {
    this.customIcon = customIcon;
    final allMarkers = <Marker>{};
    for (var zone in _zones) {
      if (zone.type == ZoneType.flagged) {
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

  void setMapController(GoogleMapController controller) {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
  }

  void _reclusterZones() {
    final newZones = Zone.reclusterZones(_zones, clusterDistance: 300);
    _zones = newZones;
    _updateMap(_zones);
    notifyListeners();
  }

  void handleMapLongPress(
      LatLng position,
      BitmapDescriptor icon,
      BuildContext context,
      MyConstants constants,
      ) {
    String? selectedDangerTag;
    String? selectedLighting;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: MyConstants.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: MyConstants.secondaryColor, width: 2),
            ),
            title: Text('Flag Danger Zone',
                style: TextStyle(
                  color: MyConstants.secondaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: MyConstants.primaryColor,
                  style: TextStyle(color: MyConstants.secondaryColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: MyConstants.primaryColor.withOpacity(0.9),
                    labelText: 'Danger Type',
                    labelStyle: TextStyle(color: MyConstants.secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MyConstants.secondaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MyConstants.secondaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: MyConstants.secondaryColor, width: 2),
                    ),
                  ),
                  items: const ['Theft', 'Assault', 'Accident', 'Natural Hazard', 'Other']
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: TextStyle(
                            color: MyConstants.secondaryColor)),
                  ))
                      .toList(),
                  onChanged: (value) => selectedDangerTag = value,
                  icon: Icon(Icons.arrow_drop_down,
                      color: MyConstants.secondaryColor),
                  borderRadius: BorderRadius.circular(10),
                  focusColor: MyConstants.primaryColor.withAlpha(80),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  dropdownColor: MyConstants.primaryColor,
                  style: TextStyle(color: MyConstants.secondaryColor),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: MyConstants.primaryColor.withOpacity(0.9),
                    labelText: 'Lighting Condition',
                    labelStyle: TextStyle(color: MyConstants.secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MyConstants.secondaryColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: MyConstants.secondaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: MyConstants.secondaryColor, width: 2),
                    ),
                  ),
                  items: const ['Poor', 'Well']
                      .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: TextStyle(
                            color: MyConstants.secondaryColor)),
                  ))
                      .toList(),
                  onChanged: (value) => selectedLighting = value,
                  icon: Icon(Icons.arrow_drop_down,
                      color: MyConstants.secondaryColor),
                  borderRadius: BorderRadius.circular(10),
                  focusColor: MyConstants.primaryColor.withAlpha(80),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(
                        color: MyConstants.secondaryColor,
                        fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  if (selectedDangerTag != null && selectedLighting != null) {
                    _addFlaggedZone(
                      position: position,
                      icon: icon,
                      dangerTag: selectedDangerTag!,
                      lighting: selectedLighting!,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text('Confirm',
                    style: TextStyle(
                        color: MyConstants.secondaryColor,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
  void _addFlaggedZone({
    required LatLng position,
    required BitmapDescriptor icon,
    required String dangerTag,
    required String lighting,
  }) {
    final newZone = Zone(
      id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
      center: position,
      radius: 0,
      dangerLevel: 0,
      type: ZoneType.flagged,
      count: 1,
      dangerTag: dangerTag,
      lighting: lighting,
    );

    _flaggedZones[newZone.id] = newZone;
    _zones.add(newZone);

    _markers.add(Marker(
      markerId: MarkerId(newZone.id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(
        title: 'Danger: $dangerTag',
        snippet: 'Lighting: $lighting',
      ),
    ));

    notifyListeners();
  }


  void onMapLongPress(LatLng latLng, BitmapDescriptor bitmapDescriptor) {
    final newZone = Zone(
      id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
      center: latLng,
      radius: 0,
      dangerLevel: 0,
      type: ZoneType.flagged,
      count: 1,
    );
    _zones.add(newZone);
    _markers.add(Marker(
      markerId: MarkerId(newZone.id),
      position: latLng,
      icon: bitmapDescriptor,
      infoWindow: const InfoWindow(title: "Custom Dropped Pin"),
    ));
    notifyListeners();
  }

  void snoozeAlert() {
    _isWarningActive = false;
    _notifiedZones.clear();
    _notifiedZoneId = "";
    notifyListeners();
  }

  Future<void> centerOnZone(Zone zone) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(zone.center, 18),
    );
  }
}
