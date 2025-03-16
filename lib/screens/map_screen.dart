import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import 'package:safezones/utils/map_config.dart';
import 'package:safezones/widgets/alert_carousel.dart';
import 'package:safezones/widgets/top_panel.dart';
import '../providers/map_provider.dart';
import '../models/zone_model.dart' as custom;
import 'package:safezones/widgets/alert_panel.dart';
import '../providers/settings_provider.dart';
import '../widgets/warning.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  BitmapDescriptor? customUserIcon;
  BitmapDescriptor? customPinIcon;

  @override
  void initState() {
    super.initState();
    _initializeMap();
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

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final backgroundColor = MyConstants.getBackgroundColor(settings.darkMode);
    final textColor = MyConstants.getTextColor(settings.darkMode);

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
              ElevatedButton(
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        border: Border.all(
          color: mapProvider.isInDangerZone ? Colors.red : Colors.transparent,
          width: mapProvider.isInDangerZone ? 8.0 : 0.0,
        ),
      ),
      child: Scaffold(
        backgroundColor: MyConstants.primaryColor,
        body: Stack(
          children: [
            mapProvider.isLoading || mapProvider.currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : Consumer2<MapProvider, SettingsProvider>(
                    builder: (context, mapProvider, settings, child) {
                      return GoogleMap(
                        style: settings.darkMode
                            ? MapConfig.mapStyleDark
                            : MapConfig.mapStyle,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            mapProvider.currentPosition?.latitude ?? 0.0,
                            mapProvider.currentPosition?.longitude ?? 0.0,
                          ),
                          zoom: 19,
                          tilt: 60.0,
                          bearing: 30.0,
                        ),
                        onCameraMove: (CameraPosition position) {
                          mapProvider.updateCameraPosition(position);
                        },
                        circles: mapProvider.circles,
                        markers: {
                          ...mapProvider.markers,
                          if (mapProvider.currentPosition != null &&
                              customUserIcon != null)
                            Marker(
                              markerId: const MarkerId("user_location"),
                              position: LatLng(
                                mapProvider.currentPosition!.latitude,
                                mapProvider.currentPosition!.longitude,
                              ),
                              icon: customUserIcon!,
                            ),
                        },
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onMapCreated: (controller) {
                          mapProvider.setMapController(controller);
                        },
                        onLongPress: (LatLng latLng) {
                          mapProvider.handleMapLongPress(latLng, context);
                        },
                      );
                    },
                  ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MyConstants.screenHeight(context) * .25,
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
                      left: 10,
                      right: 10,
                      bottom: MediaQuery.of(context).padding.bottom),
                  child: AlertsPanel(
                    userLocation: mapProvider.currentPosition,
                    dangerZones: mapProvider.zones,
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
