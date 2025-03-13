import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../models/zone_model.dart';
import '../providers/settings_provider.dart';

class AlertsCarousel extends StatelessWidget {
  final Position? userLocation;
  final List<Zone> dangerZones;
  final Function(Zone zone)? onZoneSelected;

  const AlertsCarousel({
    super.key,
    required this.userLocation,
    required this.dangerZones,
    this.onZoneSelected,
  });

  String getAvatarPath(Zone zone) {
    var tag = zone.dangerTag ?? 'Other';
    if (tag == 'Natural Hazard') {
      tag = 'hazard';
    }
    return 'assets/avatars/${tag.toLowerCase()}_near.png';
  }

  String getDistance(Zone zone) {
    if (userLocation == null) return "unknown";
    final meters = Geolocator.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      zone.center.latitude,
      zone.center.longitude,
    );
    return "${(meters / 1000).toStringAsFixed(1)} km away";
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    // Filter zones that are within the alert radius.
    final nearbyZones = dangerZones.where((zone) {
      if (userLocation == null) return false;
      final distance = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation!.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      return distance <= (settings.alertRadius + zone.radius);
    }).toList();

    if (nearbyZones.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: nearbyZones.length,
        itemBuilder: (context, index) {
          final zone = nearbyZones[index];
          return GestureDetector(
            onTap: () => onZoneSelected?.call(zone),
            child: Container(
              width: MyConstants.screenWidth(context) * .7,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MyConstants.primaryColor,
                borderRadius: MyConstants.roundness,
                border: Border.all(
                  color: zone.type == ZoneType.flag
                      ? const Color.fromARGB(255, 52, 50, 43)
                      : Colors.redAccent,
                  width: .5,
                ),
              ),
              child: Row(
                children: [
                  // Left: Text info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            zone.dangerTag ??
                                (zone.type == ZoneType.flag
                                    ? "Flagged Zone"
                                    : "Danger Zone"),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            getDistance(zone),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.near_me,
                                color: Colors.white70, size: 14),
                            SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Tap to navigate",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: Image container
                  Container(
                    width: 80,
                    height: 800,
                    decoration: BoxDecoration(
                      color: zone.type == ZoneType.flag
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.redAccent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      getAvatarPath(zone),
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
