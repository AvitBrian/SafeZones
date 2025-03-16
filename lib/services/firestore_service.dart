import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> fetchFlaggedZones(LatLng center, double radius,
      {DocumentSnapshot? lastDocument}) async {
    Query query = _db
        .collection('flaggedZones')
        .where('location',
            isGreaterThan:
                GeoPoint(center.latitude - radius, center.longitude - radius))
        .where('location',
            isLessThan:
                GeoPoint(center.latitude + radius, center.longitude + radius));

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
        timeOfDay: data['timeOfDay'],
        policeDistance: data['policeDistance']?.toDouble(),
        hospitalDistance: data['hospitalDistance']?.toDouble(),
        buildingDistance: data['buildingDistance']?.toDouble(),
        roadDistance: data['roadDistance']?.toDouble(),
      );
    }).toList();

    DocumentSnapshot? lastDoc =
        snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return {
      'zones': zones,
      'lastDocument': lastDoc,
    };
  }

  Future<void> addFlaggedZone(LatLng position, String dangerTag, String userId,
      {double? policeDistance,
      double? hospitalDistance,
      double? buildingDistance,
      double? roadDistance,
      Map<String, dynamic>? weatherData}) async {
    try {
      final double safePoliceDistance = policeDistance ?? 0.0;
      final double safeHospitalDistance = hospitalDistance ?? 0.0;
      final double safeBuildingDistance = buildingDistance ?? 0.0;
      final double safeRoadDistance = roadDistance ?? 0.0;

      final docRef = _db.collection('flaggedZones').doc();
      final timeOfDay = _getTimeOfDay(DateTime.now());

      debugPrint(
          '⭐ ABOUT TO SAVE - Police: $safePoliceDistance, Hospital: $safeHospitalDistance, Building: $safeBuildingDistance, Road: $safeRoadDistance');

      final Map<String, dynamic> zoneData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': GeoPoint(position.latitude, position.longitude),
        'dangerTag': dangerTag,
        'timeOfDay': timeOfDay,
        'createdAt': Timestamp.now(),
        'userId': userId,
        'policeDistance': safePoliceDistance,
        'hospitalDistance': safeHospitalDistance,
        'buildingDistance': safeBuildingDistance,
        'roadDistance': safeRoadDistance,
        'weatherData': weatherData,
      };

      await docRef.set(zoneData);

      debugPrint(
          '✅ Successfully added flagged zone to Firestore with ID: ${docRef.id}');
    } catch (e) {
      debugPrint('❌ Error adding flagged zone: $e');
      rethrow;
    }
  }

  Future<int> countUserFlags(String userId) async {
    if (userId.isEmpty) return 0;

    try {
      final QuerySnapshot snapshot = await _db
          .collection('flaggedZones')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error counting user flags: $e');
      return 0;
    }
  }

  // Helper method to determine time of day
  String _getTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }
}
