import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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
      print("📥 Loading zone \${doc.id} | userId: \${data['userId']}");
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
          confidence: data['confidence']?.toDouble(),
          userId: data['userId']?.toString(),
          upVotes: data['upVotes']?.toInt(),
          downVotes: data['downVotes']?.toInt(),
          voteIds: Map<String, dynamic>.from(data['voteIds'] ?? {}));
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
      Map<String, dynamic>? weatherData}) async {
    try {
      final double safePoliceDistance = policeDistance ?? 0.0;
      final double safeHospitalDistance = hospitalDistance ?? 0.0;
      final double safeBuildingDistance = buildingDistance ?? 0.0;

      final docRef = _db.collection('flaggedZones').doc();
      final timeOfDay = _getTimeOfDay(DateTime.now());

      debugPrint(
          '⭐ ABOUT TO SAVE - Police: \$safePoliceDistance, Hospital: \$safeHospitalDistance, Building: \$safeBuildingDistance');

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
        'weatherData': weatherData,
      };

      await docRef.set(zoneData);

      debugPrint(
          '✅ Successfully added flagged zone to Firestore with ID: \${docRef.id}');
    } catch (e) {
      debugPrint('❌ Error adding flagged zone: \$e');
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
      debugPrint('Error counting user flags: \$e');
      return 0;
    }
  }

  Future<void> deleteUserFlags(String userId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('flaggedZones')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }

    debugPrint(
        "✅ Deleted \${querySnapshot.docs.length} flags for user \$userId");
  }

  Future<bool> isLocationAlreadyPredicted(LatLng position,
      {double threshold = 30}) async {
    try {
      final snapshot = await _db
          .collection('flaggedZones')
          .where('userId', isEqualTo: 'AI')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final existingLat = data['latitude'];
        final existingLon = data['longitude'];

        if (existingLat != null && existingLon != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            existingLat.toDouble(),
            existingLon.toDouble(),
          );
          if (distance < threshold) return true;
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking existing prediction: \$e');
    }
    return false;
  }

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

  Future<void> voteOnZone({
    required String zoneId,
    required String userId,
    required bool isUpvote,
  }) async {
    final docRef = _db.collection('flaggedZones').doc(zoneId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Zone not found");
      }

      final data = snapshot.data()!;
      Map<String, dynamic> voteIds =
          Map<String, dynamic>.from(data['voteIds'] ?? {});

      // If already voted, prevent double voting
      if (voteIds.containsKey(userId)) return;

      int upVotes = (data['upVotes'] ?? 0) as int;
      int downVotes = (data['downVotes'] ?? 0) as int;

      voteIds[userId] = isUpvote ? 'yes' : 'no';
      if (isUpvote) {
        upVotes++;
      } else {
        downVotes++;
      }

      transaction.update(docRef, {
        'upVotes': upVotes,
        'downVotes': downVotes,
        'voteIds': voteIds,
      });
    });
  }
}
