import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;

      if (results.isEmpty) return null;

      double minDistance = double.infinity;
      for (var place in results) {
        final placeLat = place['geometry']['location']['lat'];
        final placeLng = place['geometry']['location']['lng'];
        final distance = Geolocator.distanceBetween(latitude, longitude, placeLat, placeLng);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
      return minDistance; // returns the distance in meters
    } else {
      // Handle error accordingly.
      return null;
    }
  }
}
