import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

extension on List<LatLng> {
  double calculateSpread() {
    if (length <= 1) return 0;

    double maxDistance = 0;
    for (int i = 0; i < length; i++) {
      for (int j = i + 1; j < length; j++) {
        final distance = Zone.calculateDistance(this[i], this[j]);
        maxDistance = max(maxDistance, distance);
      }
    }
    return maxDistance;
  }
}

enum ZoneType { flag, dangerZone }

class Zone {
  final String id;
  final LatLng center;
  final double radius;
  final double dangerLevel;
  final ZoneType type;
  final int count;
  final String? dangerTag;
  final double? policeDistance;
  final double? hospitalDistance;

  Zone({
    required this.id,
    required this.center,
    required this.type,
    this.radius = 0,
    this.dangerLevel = 0,
    this.count = 1,
    this.dangerTag,
    this.policeDistance,
    this.hospitalDistance,
  });

  factory Zone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Zone(
      id: doc.id,
      center: LatLng(data['latitude'], data['longitude']),
      type: ZoneType.flag,
      dangerTag: data['dangerTag'],
      policeDistance: data['policeDistance']?.toDouble(),
      hospitalDistance: data['hospitalDistance']?.toDouble(),
    );
  }

  factory Zone.dangerZone(String id, LatLng center, List<Zone> flaggedZones) {
    return Zone(
      id: id,
      center: center,
      type: ZoneType.dangerZone,
      radius: 300.0,
      dangerLevel: (flaggedZones.length * 0.15).clamp(0.1, 1.0),
      count: flaggedZones.length,
    );
  }

  static List<Zone> createZones(List<LatLng> coordinates, {double clusterDistance = 300, String? dangerTag}) {
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
          type: ZoneType.flag,
          dangerTag: dangerTag,
        ));
      }
    }

    final mergedClusters = mergeOverlappingClusters(clusters);

    return [...mergedClusters, ...flaggedZones];
  }

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
      type: ZoneType.dangerZone,
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
      type: ZoneType.dangerZone,
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

  static double calculateDistance(LatLng point1, LatLng point2) {
    const p = pi / 180;
    final a = 0.5 - cos((point2.latitude - point1.latitude) * p) / 2 + 
              cos(point1.latitude * p) * cos(point2.latitude * p) * 
              (1 - cos((point2.longitude - point1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R; R = 6371 km, result in meters
  }

  static List<Zone> reclusterZones(List<Zone> zones, {double? clusterDistance}) {
    final flaggedLocations = zones
        .where((zone) => zone.type == ZoneType.flag)
        .map((zone) => zone.center)
        .toList();

    final customClusterDistance = clusterDistance ??
        _calculateDynamicClusterDistance(flaggedLocations);

    final newZones = createZones(
        flaggedLocations,
        clusterDistance: customClusterDistance
    );

    final dangerZones = zones.where((zone) => zone.type != ZoneType.flag).toList();
    newZones.addAll(dangerZones);

    return newZones;
  }

  static double _calculateDynamicClusterDistance(List<LatLng> coordinates) {
    if (coordinates.length <= 3) return 300.0;

    final spread = coordinates.calculateSpread();

    if (spread < 500) return 300.0;
    if (spread < 1000) return 500.0;
    if (spread < 2000) return 750.0;
    return 1000.0;
  }
}