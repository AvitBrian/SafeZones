import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ZoneType { flagged, danger }

class Zone {
  final String id;
  final LatLng center;
  final double radius;
  final double dangerLevel;
  final ZoneType type;
  final int count;
  final String? dangerTag;
  final String? lighting;

  Zone({
    required this.id,
    required this.center,
    required this.radius,
    required this.dangerLevel,
    required this.type,
    required this.count,
    this.dangerTag,
    this.lighting,
  });


  /// Creates clusters for danger zones
  static List<Zone> createZones(List<LatLng> coordinates,
      {double clusterDistance = 300, String? dangerTag, String? lighting}) {
    final clusters = <Zone>[];
    final coords = List<LatLng>.from(coordinates);
    final flaggedZones = <Zone>[];

    while (coords.isNotEmpty) {
      final current = coords.removeAt(0);
      final cluster = [current];

      coords.removeWhere((point) {
        if (calculateDistance(current, point) < clusterDistance) {
          cluster.add(point);
          return true;
        }
        return false;
      });

      if (cluster.length > 1) {
        clusters.add(createCluster(cluster));
      } else {
        flaggedZones.add(Zone(
          id: 'flagged_${DateTime.now().millisecondsSinceEpoch}',
          center: cluster.first,
          radius: 0,
          dangerLevel: 0,
          type: ZoneType.flagged,
          count: 1,
        ));
      }
    }

    final mergedClusters = mergeOverlappingClusters(clusters);
    return [...mergedClusters, ...flaggedZones];
  }

  /// Creates a single Danger Zone cluster from a list of points.
  static Zone createCluster(List<LatLng> points) {
    double maxDistance = 0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final distance = calculateDistance(points[i], points[j]);
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }

    final radius = (maxDistance / 2).clamp(50.0, 500.0);

    return Zone(
      id: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
      center: calculateCenter(points),
      radius: radius,
      dangerLevel: (points.length * 0.15).toDouble().clamp(0.1, 1.0),
      type: ZoneType.danger,
      count: points.length,
    );
  }

  static List<Zone> mergeOverlappingClusters(List<Zone> clusters) {
    List<Zone> merged = List.from(clusters);
    bool hasOverlaps;
    do {
      hasOverlaps = false;
      for (int i = 0; i < merged.length; i++) {
        for (int j = i + 1; j < merged.length; j++) {
          if (merged[i].overlapsWith(merged[j])) {
            final combined = combineZones(merged[i], merged[j]);
            merged
              ..removeAt(j)
              ..removeAt(i)
              ..add(combined);
            hasOverlaps = true;
            break;
          }
        }
        if (hasOverlaps) break;
      }
    } while (hasOverlaps);
    return merged;
  }

  static Zone combineZones(Zone a, Zone b) {
    return Zone(
      id: 'merged_${a.id}_${b.id}',
      center: LatLng(
        (a.center.latitude * a.count + b.center.latitude * b.count) / (a.count + b.count),
        (a.center.longitude * a.count + b.center.longitude * b.count) / (a.count + b.count),
      ),
      radius: max(a.radius, b.radius),
      dangerLevel: (a.dangerLevel + b.dangerLevel).toDouble().clamp(0.1, 1.0),
      type: ZoneType.danger,
      count: a.count + b.count,
    );
  }

  bool overlapsWith(Zone other) {
    return calculateDistance(center, other.center) < (radius + other.radius);
  }

  static LatLng calculateCenter(List<LatLng> points) {
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  static double calculateDistance(LatLng pointA, LatLng pointB) {
    const earthRadius = 6371e3;
    final lat1 = pointA.latitude * pi / 180;
    final lat2 = pointB.latitude * pi / 180;
    final latDiff = (pointB.latitude - pointA.latitude) * pi / 180;
    final lonDiff = (pointB.longitude - pointA.longitude) * pi / 180;
    final a = sin(latDiff / 2) * sin(latDiff / 2) +
        cos(lat1) * cos(lat2) * sin(lonDiff / 2) * sin(lonDiff / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Re-clusters flagged zones into danger zones
  static List<Zone> reclusterZones(List<Zone> zones, {double clusterDistance = 300}) {
    final flaggedLocations = zones
        .where((zone) => zone.type == ZoneType.flagged)
        .map((zone) => zone.center)
        .toList();

    final newZones = createZones(flaggedLocations, clusterDistance: clusterDistance);

    final dangerZones = zones.where((zone) => zone.type != ZoneType.flagged).toList();
    newZones.addAll(dangerZones);

    return newZones;
  }
}