import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PlacesService {
  final String apiKey = 'AIzaSyClx316yUjXy8BziS5raKTNjdDUkriX_g8';

  Future<double?> getDistanceToClosestPlace({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 5000,
  }) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&type=$type&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check for Google API errors
        if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
          debugPrint('Google Places API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
          return 0.0; 
        }
        
        final results = data['results'] as List;

        if (results.isEmpty) {
          debugPrint('No $type found within $radius meters');
          return 0.0;
        }

        double minDistance = double.infinity;
        for (var place in results) {
          final placeLat = place['geometry']['location']['lat'];
          final placeLng = place['geometry']['location']['lng'];
          final distance = Geolocator.distanceBetween(latitude, longitude, placeLat, placeLng);
          if (distance < minDistance) {
            minDistance = distance;
          }
        }
        debugPrint('Closest $type is $minDistance meters away');
        return minDistance; 
      } else {
        debugPrint('Google Places API returned status code: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error in getDistanceToClosestPlace for $type: $e');
      return 0.0; 
    }
  }
}
