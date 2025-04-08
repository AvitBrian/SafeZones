import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/locations.dart'; // Import the locations file

class PlacesService {
  final String apiKey = 'AIzaSyClx316yUjXy8BziS5raKTNjdDUkriX_g8';

  // Helper method to get fallback distance from predefined locations
  double _getFallbackDistance(double lat, double lon, String category) {
    // Retrieve the predefined locations for the specific category
    final list = _getListForCategory(category);

    if (list != null && list.isNotEmpty) {
      double minDistance = double.infinity;

      // Calculate the distance to each predefined location
      for (var coords in list) {
        double distance =
            Geolocator.distanceBetween(lat, lon, coords[0], coords[1]);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }

      return minDistance;
    }

    return 5000.0;
  }

  // Map categories to their respective lists in Locations
  List<List<double>>? _getListForCategory(String category) {
    switch (category) {
      case 'bus_station':
        return Locations.busStations;
      case 'market':
        return Locations.markets;
      default:
        return null; // No predefined list for this category
    }
  }

  Future<double?> getDistanceToClosestPlace({
    required double latitude,
    required double longitude,
    required List<String> types, // Accept a list of types
    int radius = 5000,
  }) async {
    double? minDistanceOverall = null;
    String closestPlaceName = ''; // To store the name of the closest place

    for (var type in types) {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&type=$type&key=$apiKey';

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // Check for Google API errors
          if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
            debugPrint(
                'Google Places API error for $type: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
            continue; // Skip to the next type if there's an error
          }

          final results = data['results'] as List;

          if (results.isEmpty) {
            debugPrint('No $type found within $radius meters');
            continue; // Skip to the next type if no results are found
          }

          double minDistanceForType = double.infinity;
          String closestPlaceNameForType = '';

          for (var place in results) {
            final placeLat = place['geometry']['location']['lat'];
            final placeLng = place['geometry']['location']['lng'];
            final distance = Geolocator.distanceBetween(
                latitude, longitude, placeLat, placeLng);
            if (distance < minDistanceForType) {
              minDistanceForType = distance;
              closestPlaceNameForType =
                  place['name'] ?? 'Unnamed Place'; // Store the name
            }
          }

          // Log the closest place's name and distance for debugging
          debugPrint(
              'Closest $type: $closestPlaceNameForType is $minDistanceForType meters away');

          // Update the overall closest distance if this type has a closer place
          if (minDistanceOverall == null ||
              minDistanceForType < minDistanceOverall) {
            minDistanceOverall = minDistanceForType;
            closestPlaceName = closestPlaceNameForType;
          }
        } else {
          debugPrint(
              'Google Places API returned status code for $type: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error in getDistanceToClosestPlace for $type: $e');
      }
    }

    // If no results were found for any type, fall back to predefined locations
    if (minDistanceOverall == null) {
      for (var type in types) {
        final fallbackDistance =
            _getFallbackDistance(latitude, longitude, type);
        if (fallbackDistance < (minDistanceOverall ?? double.infinity)) {
          minDistanceOverall = fallbackDistance;
        }
      }
    }

    // Log the overall closest place's name and distance for debugging
    debugPrint(
        'Overall Closest Place: $closestPlaceName is $minDistanceOverall meters away');

    return minDistanceOverall;
  }
}
