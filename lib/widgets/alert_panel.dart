import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../models/zone_model.dart';
import '../providers/settings_provider.dart';
import '../providers/map_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlertsPanel extends StatefulWidget {
  final Position? userLocation;
  final List<Zone> dangerZones;
  final Function(Zone zone)? onZoneSelected;
  final BitmapDescriptor? customPinIcon;

  const AlertsPanel({
    super.key,
    required this.userLocation,
    required this.dangerZones,
    this.onZoneSelected,
    this.customPinIcon,
  });

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    // Filter zones within alert distance.
    final nearbyZones = widget.userLocation == null
        ? []
        : widget.dangerZones.where((zone) {
      final distance = Geolocator.distanceBetween(
        widget.userLocation!.latitude,
        widget.userLocation!.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      return distance <= (settings.alertRadius + zone.radius);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyConstants.secondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alerts header and expandable list.
          widget.userLocation == null || widget.dangerZones.isEmpty
              ? _buildNoAlerts()
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggleExpanded,
                child: Row(
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: _isExpanded ? 0 : 0.5,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: MyConstants.primaryColor,
                      ),
                    ),
                    Text(
                      "Nearby Alerts",
                      style: TextStyle(
                        color: MyConstants.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${nearbyZones.length} active zones",
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
              SizeTransition(
                sizeFactor: _heightFactor,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: nearbyZones.length,
                        itemBuilder: (context, index) {
                          final zone = nearbyZones[index];
                          return _buildAlertItem(
                            zone.type == ZoneType.flagged
                                ? "Flagged Zone"
                                : "Danger Zone",
                            "${(Geolocator.distanceBetween(
                                widget.userLocation!.latitude,
                                widget.userLocation!.longitude,
                                zone.center.latitude,
                                zone.center.longitude) /
                                1000)
                                .toStringAsFixed(1)} km away",
                            zone.type == ZoneType.flagged
                                ? Colors.amber
                                : Colors.redAccent,
                            onTap: () => widget.onZoneSelected?.call(zone),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Provider.of<MapProvider>(context, listen: false)
                        .centerOnUser();
                  },
                  child: const Text("Center"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final mapProvider = Provider.of<MapProvider>(context, listen: false);
                    final cameraPos = mapProvider.currentCameraPosition;
                    if (cameraPos != null) {
                      mapProvider.onMapLongPress(
                        cameraPos.target,
                        widget.customPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      );
                    }
                  },
                  child: const Text("Flag"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyConstants.secondaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "No nearby danger zones detected.",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildAlertItem(String tag, String distance, Color severity,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: MyConstants.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: severity, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                          color: MyConstants.textColor, fontSize: 16),
                    ),
                    Text(
                      distance,
                      style: TextStyle(
                          color: MyConstants.subtextColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
