import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import 'package:safezones/utils/map_config.dart';
import 'package:safezones/widgets/alert_carousel.dart';
import 'package:safezones/widgets/top_panel.dart';
import 'package:lottie/lottie.dart' as lottie;
import '../providers/map_provider.dart';
import '../models/zone_model.dart' as custom;
import 'package:safezones/widgets/alert_panel.dart';
import '../providers/settings_provider.dart';
import '../services/osm_service.dart';
import '../services/places_service.dart';
import '../services/weather_service.dart';
import '../widgets/warning.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  BitmapDescriptor? customUserIcon;
  BitmapDescriptor? customPinIcon;
  bool _showLottie = false;
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.updateMap(settings);
  }

  Future<void> _initializeMap() async {
    await _loadCustomMarkers();

    if (!mounted) return;

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (customPinIcon != null) {
      mapProvider.applyCustomIconToAllMarkers(customPinIcon!);
    }

    mapProvider.checkLocationPermissions(settings, context);
  }

  Future<void> _loadCustomMarkers() async {
    final userIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(125, 125)),
      'assets/avatars/user.png',
    );
    final pinIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(100, 100)),
      'assets/avatars/default.png',
    );

    if (!mounted) return;

    setState(() {
      customUserIcon = userIcon;
      customPinIcon = pinIcon;
    });
  }

  Future<void> sendPredictionData(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    const String apiUrl = 'http://54.209.56.238:8000/predict';
    debugPrint("[sendPredictionData] Starting prediction data process.");

    final currentPosition = context.read<MapProvider>().currentPosition;
    final userLat = currentPosition?.latitude ?? 0.0;
    final userLon = currentPosition?.longitude ?? 0.0;
    debugPrint("[sendPredictionData] User location: ($userLat, $userLon)");

    final osmService = OsmService();
    final placesService = PlacesService();
    final weatherService = WeatherService();

    // Fetch distances
    final buildingDistance =
        await osmService.getDistanceToNearestBuilding(userLat, userLon);
    // final roadDistance =
    //     await osmService.getDistanceToNearestRoad(userLat, userLon);
    final roadType = await osmService.getRoadType(userLat, userLon);
    final policeDistance = await placesService.getDistanceToClosestPlace(
        latitude: userLat, longitude: userLon, types: ['police']);
    final marketDistance = await placesService.getDistanceToClosestPlace(
        latitude: userLat, longitude: userLon, types: ['supermarket']);
    final busStationDistance = await placesService.getDistanceToClosestPlace(
        latitude: userLat,
        longitude: userLon,
        types: ['bus_station', 'transit_station']);
    final weatherData = await weatherService.fetchWeather(userLat, userLon);

    // Debug prints
    debugPrint("[sendPredictionData] market distance: $marketDistance m");
    debugPrint(
        "[sendPredictionData] Bus station distance: $busStationDistance m");

    // Prepare payload
    final payload = {
      "hour": DateTime.now().hour,
      "roadType": roadType,
      "weather": weatherData["weather"][0]["main"].toString().toLowerCase(),
      "buildingDistance": buildingDistance,
      "policeDistance": policeDistance,
      "marketDistance": marketDistance,
      "busStationDistance": busStationDistance,
      "latitude": userLat,
      "longitude": userLon,
    };

    debugPrint("[sendPredictionData] Payload prepared: ${jsonEncode(payload)}");

    try {
      debugPrint("[sendPredictionData] Sending POST request to $apiUrl");
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      debugPrint(
          "[sendPredictionData] Response Status Code: ${response.statusCode}");
      debugPrint("[sendPredictionData] Response Body: ${response.body}");
    } catch (e) {
      debugPrint("[sendPredictionData] Error sending prediction data: $e");
    }
  }

  void _moveCameraToClosestAIPrediction(MapProvider mapProvider) {
    final aiZones = mapProvider.zones.where((z) => z.userId == 'AI');
    final userLocation = mapProvider.currentPosition;

    if (userLocation != null && aiZones.isNotEmpty) {
      final closest = aiZones.reduce((a, b) {
        final aDist = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          a.center.latitude,
          a.center.longitude,
        );
        final bDist = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          b.center.latitude,
          b.center.longitude,
        );
        return aDist < bDist ? a : b;
      });

      mapProvider.centerOnZone(closest, closest.type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final backgroundColor = MyConstants.getBackgroundColor(settings.darkMode);
    final showAiPrediction = settings.showAiPredictions;
    if (mapProvider.currentPosition == null && !mapProvider.isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Unable to get location',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  final settings =
                      Provider.of<SettingsProvider>(context, listen: false);
                  mapProvider.checkLocationPermissions(settings, context);
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: MyConstants.secondaryColor.withBlue(110)));

    final warningMessage = mapProvider.isInDangerZone
        ? "You are in a danger zone!"
        : "You are close to a danger zone!";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapProvider.isWarningActive && !NotificationManager.isShowing) {
        NotificationManager.show(
          context,
          message: warningMessage,
          color: Colors.red,
          onSnooze: () {
            mapProvider.snoozeAlert();
          },
          zoneId: mapProvider.notifiedZoneId,
        );
      } else if (!mapProvider.isWarningActive &&
          NotificationManager.isShowing) {
        NotificationManager.hide();
      }
    });

    // Filter danger zones based on proximity and settings
    final filteredDangerZones = mapProvider.zones.where((zone) {
      final user = mapProvider.currentPosition;
      if (zone.userId == 'AI' && settings.showAiPredictions) {
        return true; // Always show AI predictions for now
      }

      if (user != null) {
        double distance = Geolocator.distanceBetween(
          user.latitude,
          user.longitude,
          zone.center.latitude,
          zone.center.longitude,
        );
        return distance <= settings.alertRadius;
      }
      return false;
    }).toList();

    return (!mapProvider.firebaseDataLoaded ||
            mapProvider.currentPosition == null)
        ? Center(
            child: lottie.Lottie.asset(
              'assets/animations/Animation - 1717779538633.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              border: Border.all(
                color: mapProvider.isInDangerZone
                    ? Colors.red
                    : Colors.transparent,
                width: mapProvider.isInDangerZone ? 8.0 : 0.0,
              ),
            ),
            child: Scaffold(
              backgroundColor: MyConstants.primaryColor,
              body: Stack(
                children: [
                  Consumer2<MapProvider, SettingsProvider>(
                    builder: (context, mapProvider, settings, child) {
                      return Stack(
                        children: [
                          GoogleMap(
                            style: settings.darkMode
                                ? MapConfig.mapStyleDark
                                : MapConfig.mapStyle,
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                mapProvider.currentPosition!.latitude,
                                mapProvider.currentPosition!.longitude,
                              ),
                              zoom: 19,
                              tilt: 60.0,
                              bearing: 30.0,
                            ),
                            onMapCreated: (controller) {
                              mapProvider.setMapController(controller);
                              setState(() {
                                _mapInitialized = true;
                              });
                            },
                            onCameraMove: (position) {
                              mapProvider.updateCameraPosition(position);
                            },
                            markers: {
                              ...mapProvider.markers,
                              if (customUserIcon != null)
                                Marker(
                                  markerId: const MarkerId("user_location"),
                                  position: LatLng(
                                    mapProvider.currentPosition!.latitude,
                                    mapProvider.currentPosition!.longitude,
                                  ),
                                  icon: customUserIcon!,
                                ),
                            },
                            circles: mapProvider.circles,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onLongPress: (latLng) =>
                                mapProvider.handleMapLongPress(latLng, context),
                          ),

                          // Optional overlay: show Lottie animation only during initialization
                          if (!_mapInitialized)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.9),
                                child: Center(
                                  child: lottie.Lottie.asset(
                                    'assets/animations/Animation - 1717779538633.json',
                                    width: 250,
                                    height: 250,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_showLottie)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: .9),
                        // Optional overlay effect
                        child: Center(
                          child: lottie.Lottie.asset(
                            'assets/animations/Animation - 1743277175794.json',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: MyConstants.screenHeight(context) * .20,
                      width: MyConstants.screenWidth(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MyConstants.secondaryColor.withValues(alpha: 1.0),
                            MyConstants.secondaryColor.withValues(alpha: 0.8),
                            MyConstants.secondaryColor.withValues(alpha: 0.3),
                            MyConstants.secondaryColor.withValues(alpha: 0.2),
                            MyConstants.secondaryColor.withValues(alpha: 0.1),
                            MyConstants.secondaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 5,
                    left: 0,
                    right: 0,
                    child: const TopBar(),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: MyConstants.screenHeight(context) * .3,
                      width: MyConstants.screenWidth(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            MyConstants.secondaryColor.withValues(alpha: 0.0),
                            MyConstants.secondaryColor.withValues(alpha: 0.1),
                            MyConstants.secondaryColor.withValues(alpha: 0.2),
                            MyConstants.secondaryColor.withValues(alpha: 0.3),
                            MyConstants.secondaryColor.withValues(alpha: 0.8),
                            MyConstants.secondaryColor.withValues(alpha: 1.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: MyConstants.screenHeight(context) * .300,
                    left: MyConstants.screenWidth(context) * .82,
                    right: MyConstants.screenWidth(context) * .03,
                    child: FloatingActionButton(
                        backgroundColor: showAiPrediction
                            ? MyConstants.primaryColor.withBlue(-50)
                            : MyConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: MyConstants.roundness,
                            side: BorderSide(
                              color: MyConstants.secondaryColor,
                              width: .9,
                            )),
                        onPressed: () async {
                          setState(() {
                            _showLottie = true;
                          });

                          final settings = context.read<SettingsProvider>();
                          final mapProvider = context.read<MapProvider>();
                          await mapProvider.updateMap(settings);

                          if (context.mounted) {
                            await sendPredictionData(context, settings);
                          }

                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _showLottie = false;
                              });
                              _moveCameraToClosestAIPrediction(mapProvider);
                            }
                          });
                        },
                        elevation: 0,
                        child: SizedBox(
                            height: 35,
                            width: 35,
                            child: Image.asset('assets/images/ai.png'))),
                  ),
                  Positioned(
                    bottom: MyConstants.screenHeight(context) * .230,
                    left: MyConstants.screenWidth(context) * .82,
                    right: MyConstants.screenWidth(context) * .03,
                    child: FloatingActionButton(
                        splashColor: MyConstants.primaryColor.withBlue(-50),
                        heroTag: null,
                        backgroundColor: MyConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: MyConstants.roundness,
                            side: BorderSide(
                              color: MyConstants.secondaryColor,
                              width: .9,
                            )),
                        onPressed: () {
                          mapProvider.centerOnUser();
                        },
                        elevation: 0,
                        child: const Icon(
                          Icons.my_location,
                          size: 33,
                        )),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(child: Container()),
                      Padding(
                        padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: MediaQuery.of(context).padding.bottom + 5),
                        child: AlertsPanel(
                          userLocation: mapProvider.currentPosition,
                          dangerZones: filteredDangerZones,
                          onZoneSelected: (custom.Zone zone) =>
                              mapProvider.centerOnZone(zone, zone.type),
                          customPinIcon: customPinIcon,
                          color: MyConstants.primaryColor,
                        ),
                      ),
                      AlertsCarousel(
                        userLocation: mapProvider.currentPosition,
                        dangerZones: mapProvider.zones,
                        onZoneSelected: (custom.Zone zone) =>
                            mapProvider.centerOnZone(zone, zone.type),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }
}
