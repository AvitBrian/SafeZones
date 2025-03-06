import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:safezones/providers/map_provider.dart';
import 'package:safezones/services/places_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> fetchFlaggedZones(LatLng center, double radius, {DocumentSnapshot? lastDocument}) async {
    Query query = _db.collection('flaggedZones')
        .where('location', isGreaterThan: GeoPoint(center.latitude - radius, center.longitude - radius))
        .where('location', isLessThan: GeoPoint(center.latitude + radius, center.longitude + radius));

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(10).get();
    List<Zone> zones = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Zone(
        id: doc.id,
        center: LatLng(data['latitude'], data['longitude']),
        radius: data['radius'] ?? 0,
        dangerLevel: data['dangerLevel'] ?? 0,
        type: ZoneType.flag,
        count: data['count'] ?? 1,
        dangerTag: data['dangerTag'] ?? '',
      );
    }).toList();

    DocumentSnapshot? lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return {
      'zones': zones,
      'lastDocument': lastDoc,
    };
  }

Future<void> addFlaggedZone(LatLng position, String dangerTag) async {
    final PlacesService _placesService = PlacesService();

    // Calculate distances to the nearest hospital and police station
    final policeDistance = await _placesService.getDistanceToClosestPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      type: 'police',
    );

    final hospitalDistance = await _placesService.getDistanceToClosestPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      type: 'hospital',
    );

    await _db.collection('flaggedZones').add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'dangerTag': dangerTag,
      'location': GeoPoint(position.latitude, position.longitude),
      'policeDistance': policeDistance,
      'hospitalDistance': hospitalDistance,
    });
  }
}