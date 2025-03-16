import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter/foundation.dart';

class OsmService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const ll.Distance _distance = ll.Distance();

  // Get distance to nearest building
  Future<double> getDistanceToNearestBuilding(
      double latitude, double longitude) async {
    try {
      final buildings = await _getNearbyBuildings(latitude, longitude, 1000);
      if (buildings.isEmpty) {
        debugPrint('No buildings found within 1km radius');
        return 0.0;
      }

      double minDistance = double.infinity;
      for (final building in buildings) {
        double? buildingLat;
        double? buildingLon;

        // Check if coordinates are in center property (for ways and relations)
        if (building['center'] != null) {
          buildingLat = building['center']['lat'];
          buildingLon = building['center']['lon'];
        } else {
          // For nodes, coordinates are directly on the element
          buildingLat = building['lat'];
          buildingLon = building['lon'];
        }

        if (buildingLat != null && buildingLon != null) {
          try {
            final distance = _calculateDistance(
                latitude,
                longitude,
                double.parse(buildingLat.toString()),
                double.parse(buildingLon.toString()));
            if (distance < minDistance) {
              minDistance = distance;
            }
          } catch (e) {
            debugPrint('Error calculating building distance: $e');
          }
        }
      }

      if (minDistance != double.infinity) {
        debugPrint('Nearest building is $minDistance meters away');
        return minDistance;
      } else {
        debugPrint('Could not calculate building distance');
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error in getDistanceToNearestBuilding: $e');
      return 0.0;
    }
  }

  // Get distance to nearest road
  Future<double> getDistanceToNearestRoad(
      double latitude, double longitude) async {
    try {
      final roads = await _getNearbyRoads(latitude, longitude, 1000);
      if (roads.isEmpty) {
        debugPrint('No roads found within 1km radius');
        return 0.0;
      }

      double minDistance = double.infinity;
      for (final road in roads) {
        // For highways with geometry
        if (road['geometry'] != null) {
          for (final node in road['geometry']) {
            final nodeLat = node['lat'];
            final nodeLon = node['lon'];

            if (nodeLat != null && nodeLon != null) {
              try {
                final distance = _calculateDistance(
                    latitude,
                    longitude,
                    double.parse(nodeLat.toString()),
                    double.parse(nodeLon.toString()));
                if (distance < minDistance) {
                  minDistance = distance;
                }
              } catch (e) {
                debugPrint('Error calculating road distance: $e');
              }
            }
          }
        }
        // For centerpoints
        else if (road['center'] != null) {
          final centerLat = road['center']['lat'];
          final centerLon = road['center']['lon'];

          if (centerLat != null && centerLon != null) {
            try {
              final distance = _calculateDistance(
                  latitude,
                  longitude,
                  double.parse(centerLat.toString()),
                  double.parse(centerLon.toString()));
              if (distance < minDistance) {
                minDistance = distance;
              }
            } catch (e) {
              debugPrint('Error calculating road center distance: $e');
            }
          }
        }
      }

      if (minDistance != double.infinity) {
        debugPrint('Nearest road is $minDistance meters away');
        return minDistance;
      } else {
        debugPrint('Could not calculate road distance');
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error in getDistanceToNearestRoad: $e');
      return 0.0;
    }
  }

  // Get distance to nearest important road or service
  Future<double> getDistanceToNearestImportantRoad(
      double latitude, double longitude) async {
    try {
      final roads = await _getNearbyImportantRoads(latitude, longitude, 1000);
      if (roads.isEmpty) {
        debugPrint('No important roads or services found within 1km radius');
        return 0.0;
      }

      double minDistance = double.infinity;
      for (final road in roads) {
        if (road['geometry'] != null) {
          for (final node in road['geometry']) {
            final nodeLat = node['lat'];
            final nodeLon = node['lon'];

            if (nodeLat != null && nodeLon != null) {
              try {
                final distance = _calculateDistance(
                    latitude,
                    longitude,
                    double.parse(nodeLat.toString()),
                    double.parse(nodeLon.toString()));
                if (distance < minDistance) {
                  minDistance = distance;
                }
              } catch (e) {
                debugPrint('Error calculating road distance: $e');
              }
            }
          }
        } else if (road['center'] != null) {
          final centerLat = road['center']['lat'];
          final centerLon = road['center']['lon'];

          if (centerLat != null && centerLon != null) {
            try {
              final distance = _calculateDistance(
                  latitude,
                  longitude,
                  double.parse(centerLat.toString()),
                  double.parse(centerLon.toString()));
              if (distance < minDistance) {
                minDistance = distance;
              }
            } catch (e) {
              debugPrint('Error calculating road center distance: $e');
            }
          }
        }
      }

      if (minDistance != double.infinity) {
        debugPrint(
            'Nearest important road or service is $minDistance meters away');
        return minDistance;
      } else {
        debugPrint('Could not calculate important road or service distance');
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error in getDistanceToNearestImportantRoad: $e');
      return 0.0;
    }
  }

  // Get distance to nearest primary road
  Future<double> getDistanceToNearestPrimaryRoad(
      double latitude, double longitude) async {
    try {
      final roads = await _getNearbyPrimaryRoads(latitude, longitude, 1000);
      if (roads.isEmpty) {
        debugPrint('No primary roads found within 1km radius');
        return 0.0;
      }

      double minDistance = double.infinity;
      for (final road in roads) {
        if (road['geometry'] != null) {
          for (final node in road['geometry']) {
            final nodeLat = node['lat'];
            final nodeLon = node['lon'];

            if (nodeLat != null && nodeLon != null) {
              try {
                final distance = _calculateDistance(
                    latitude,
                    longitude,
                    double.parse(nodeLat.toString()),
                    double.parse(nodeLon.toString()));
                if (distance < minDistance) {
                  minDistance = distance;
                }
              } catch (e) {
                debugPrint('Error calculating road distance: $e');
              }
            }
          }
        } else if (road['center'] != null) {
          final centerLat = road['center']['lat'];
          final centerLon = road['center']['lon'];

          if (centerLat != null && centerLon != null) {
            try {
              final distance = _calculateDistance(
                  latitude,
                  longitude,
                  double.parse(centerLat.toString()),
                  double.parse(centerLon.toString()));
              if (distance < minDistance) {
                minDistance = distance;
              }
            } catch (e) {
              debugPrint('Error calculating road center distance: $e');
            }
          }
        }
      }

      if (minDistance != double.infinity) {
        debugPrint('Nearest primary road is $minDistance meters away');
        return minDistance;
      } else {
        debugPrint('Could not calculate primary road distance');
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error in getDistanceToNearestPrimaryRoad: $e');
      return 0.0;
    }
  }

  // Calculate distance between two points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    final point1 = ll.LatLng(lat1, lon1);
    final point2 = ll.LatLng(lat2, lon2);
    return _distance.as(ll.LengthUnit.Meter, point1, point2);
  }

  // Get nearby buildings using Overpass API
  Future<List<Map<String, dynamic>>> _getNearbyBuildings(
      double latitude, double longitude, double radius) async {
    final query = """
      [out:json];
      (
        node["building"](around:$radius,$latitude,$longitude);
        way["building"](around:$radius,$latitude,$longitude);
        relation["building"](around:$radius,$latitude,$longitude);
      );
      out center;
    """;

    return _executeOverpassQuery(query);
  }

  // Get nearby roads using Overpass API
  Future<List<Map<String, dynamic>>> _getNearbyRoads(
      double latitude, double longitude, double radius) async {
    final query = """
      [out:json];
      (
        way["highway"](around:$radius,$latitude,$longitude);
      );
      out geom;
    """;

    return _executeOverpassQuery(query);
  }

  // Get nearby important roads using Overpass API
  Future<List<Map<String, dynamic>>> _getNearbyImportantRoads(
      double latitude, double longitude, double radius) async {
    final query = """
      [out:json];
      (
        way["highway"="trunk"](around:$radius,$latitude,$longitude);
        way["highway"="primary"](around:$radius,$latitude,$longitude);
        way["highway"="secondary"](around:$radius,$latitude,$longitude);
        node["amenity"="hospital"](around:$radius,$latitude,$longitude);
        node["amenity"="police"](around:$radius,$latitude,$longitude);
      );
      out geom;
    """;

    return _executeOverpassQuery(query);
  }

  // Get nearby primary roads using Overpass API
  Future<List<Map<String, dynamic>>> _getNearbyPrimaryRoads(
      double latitude, double longitude, double radius) async {
    final query = """
      [out:json];
      (
        way["highway"="primary"](around:$radius,$latitude,$longitude);
      );
      out geom;
    """;

    return _executeOverpassQuery(query);
  }

  // Execute Overpass API query
  Future<List<Map<String, dynamic>>> _executeOverpassQuery(String query) async {
    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'] == null) {
          debugPrint('Overpass API returned null elements: ${response.body}');
          return [];
        }
        return List<Map<String, dynamic>>.from(data['elements'] ?? []);
      } else {
        debugPrint(
            'Failed to query Overpass API: ${response.statusCode}, Body: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error querying Overpass API: $e');
      return [];
    }
  }
}
