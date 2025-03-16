import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../models/zone_model.dart';
import '../providers/settings_provider.dart';
import 'package:carousel_slider/carousel_slider.dart';

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

    final double viewportFraction = nearbyZones.length == 1 ? .95 : 0.85;

    return CarouselSlider.builder(
      itemCount: nearbyZones.length,
      options: CarouselOptions(
        height: 135,
        viewportFraction: viewportFraction,
        enlargeCenterPage: nearbyZones.length > 1,
        enableInfiniteScroll: nearbyZones.length > 1,
        autoPlay: nearbyZones.length > 1,
        autoPlayInterval: const Duration(seconds: 7),
        autoPlayAnimationDuration: const Duration(milliseconds: 1200),
        pauseAutoPlayOnTouch: true,
      ),
      itemBuilder: (context, index, realIndex) {
        final zone = nearbyZones[index];
        return GestureDetector(
          onTap: () => onZoneSelected?.call(zone),
          child: Container(
            width: MyConstants.screenWidth(context),
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 13),
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            decoration: BoxDecoration(
              color: MyConstants.primaryColor,
              borderRadius: MyConstants.roundness,
              border: Border.all(
                color: zone.type == ZoneType.flag
                    ? MyConstants.secondaryColor
                    : Colors.redAccent,
                width: .8,
              ),
            ),
            child: Row(
              children: [
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
                      const Row(
                        children: [
                          Icon(Icons.near_me, color: Colors.white70, size: 14),
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
                Container(
                  width: 80,
                  height: 80,
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
    );
  }
}
