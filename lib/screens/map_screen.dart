import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import 'package:safezones/utils/map_config.dart';
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
    _loadCustomMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      mapProvider.checkLocationPermissions(settings, context);
    });
  }

  Future<void> _loadCustomMarkers() async {
    final userIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(125, 125)),
      'assets/avatars/3d-map_2.png',
    );
    final pinIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(100, 100)),
      'assets/avatars/3d-map.png',
    );
    setState(() {
      customUserIcon = userIcon;
      customPinIcon = pinIcon;
    });
    if (customPinIcon != null) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      mapProvider.applyCustomIconToAllMarkers(customPinIcon!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
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
      } else if (!mapProvider.isWarningActive && NotificationManager.isShowing) {
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
                : GoogleMap(
              style: MapConfig.mapStyle,
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
                if (mapProvider.currentPosition != null && customUserIcon != null)
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
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: const TopBar(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 10,
              left: 10,
              right: 10,
              child: AlertsPanel(
                userLocation: mapProvider.currentPosition,
                dangerZones: mapProvider.zones,
                onZoneSelected: (custom.Zone zone) => mapProvider.centerOnZone(zone, zone.type),
                customPinIcon: customPinIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}