import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:safezones/models/zone_model.dart';
import 'package:safezones/services/auth_service.dart';
import 'package:safezones/utils/constants.dart';
import 'package:safezones/utils/snack_bar.dart';
import 'package:safezones/providers/settings_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';

class AlertsCarousel extends StatefulWidget {
  final Position? userLocation;
  final List<Zone> dangerZones;
  final Function(Zone zone)? onZoneSelected;

  const AlertsCarousel({
    super.key,
    required this.userLocation,
    required this.dangerZones,
    this.onZoneSelected,
  });

  @override
  State<AlertsCarousel> createState() => _AlertsCarouselState();
}

class _AlertsCarouselState extends State<AlertsCarousel> {
  late List<Zone> visibleZones;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthService>();
    final userId = auth.currentUser?.uid;

    final nearbyZones = widget.dangerZones.where((zone) {
      if (widget.userLocation == null) return false;
      if (!settings.showAiPredictions && zone.userId == 'AI') return false;
      if (zone.userId == 'AI' && (zone.confidence ?? 0) < 0.5) return false;

      final distance = Geolocator.distanceBetween(
        widget.userLocation!.latitude,
        widget.userLocation!.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      return distance <= (settings.alertRadius + zone.radius);
    }).toList();

    if (nearbyZones.isEmpty) return const SizedBox.shrink();
    visibleZones = nearbyZones.take(5).toList();

    return SizedBox(
      height: MyConstants.screenHeight(context) * .15,
      child: visibleZones.length == 1
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCard(context, visibleZones.first, userId),
            )
          : Swiper(
              itemCount: visibleZones.length,
              autoplay: true,
              autoplayDelay: 5000,
              layout: SwiperLayout.TINDER,
              itemBuilder: (context, index) {
                final zone = visibleZones[index];
                return _buildCard(context, zone, userId);
              },
              itemWidth: MediaQuery.of(context).size.width * 1.0,
              itemHeight: 200,
            ),
    );
  }

  Widget _buildCard(BuildContext context, Zone zone, String? userId) {
    final isAi = zone.userId == 'AI';
    final voteData = (zone.voteIds ?? <String, dynamic>{});
    final hasVoted = voteData.containsKey(userId);

    return GestureDetector(
      onTap: () {
        if (isAi && !hasVoted && userId != null) {
          _showVoteDialog(context, zone, userId);
        } else {
          widget.onZoneSelected?.call(zone);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MyConstants.primaryColor,
          borderRadius: MyConstants.roundness,
          border: Border.all(
            color: zone.type == ZoneType.flag
                ? MyConstants.secondaryColor
                : Colors.redAccent,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAi && zone.confidence != null
                        ? "${_capitalize(zone.dangerTag)} (${(zone.confidence! * 100).toStringAsFixed(0)}%)"
                        : (zone.dangerTag ??
                            (zone.type == ZoneType.flag
                                ? "Flagged Zone"
                                : "Danger Zone")),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _getDistance(zone),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.near_me, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text("Tap to navigate",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  if (isAi)
                    Row(
                      children: [
                        Icon(Icons.thumb_up,
                            color: Colors.greenAccent, size: 16),
                        Text(
                            " ${zone.voteIds?.values.where((v) => v == 'yes').length ?? 0}",
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 8),
                        Icon(Icons.thumb_down,
                            color: Colors.redAccent, size: 16),
                        Text(
                            " ${zone.voteIds?.values.where((v) => v == 'no').length ?? 0}",
                            style: const TextStyle(color: Colors.white)),
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
                    ? MyConstants.secondaryColor.withAlpha(100)
                    : Colors.redAccent.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  _getAvatarPath(zone),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoteDialog(BuildContext context, Zone zone, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MyConstants.primaryColor,
        title: Text("Vote on ${zone.dangerTag ?? "Zone"}",
            style: TextStyle(color: MyConstants.textColor)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => _submitVote(context, zone, userId, true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.thumb_up, color: Colors.greenAccent, size: 32),
                  SizedBox(height: 4),
                  Text("Agree", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _submitVote(context, zone, userId, false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.thumb_down, color: Colors.redAccent, size: 32),
                  SizedBox(height: 4),
                  Text("Disagree", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVote(
      BuildContext context, Zone zone, String userId, bool isUpvote) async {
    await FirestoreService().voteOnZone(
      zoneId: zone.id,
      userId: userId,
      isUpvote: isUpvote,
    );

    setState(() {
      visibleZones = visibleZones.map((z) {
        if (z.id == zone.id) {
          final updatedVotes = {...?z.voteIds, userId: isUpvote ? 'yes' : 'no'};
          return z.copyWith(voteIds: updatedVotes);
        }
        return z;
      }).toList();
    });

    openSnackBar(context, isUpvote ? "Thanks for your vote!" : "Vote recorded",
        isUpvote ? Colors.green : Colors.red);

    if (context.mounted) {
      Navigator.of(context).pop();
      widget.onZoneSelected?.call(zone);
    }
  }

  String _getDistance(Zone zone) {
    if (widget.userLocation == null) return "unknown";
    final meters = Geolocator.distanceBetween(
      widget.userLocation!.latitude,
      widget.userLocation!.longitude,
      zone.center.latitude,
      zone.center.longitude,
    );
    return "${(meters / 1000).toStringAsFixed(1)} km away";
  }

  String _capitalize(String? input) {
    if (input == null || input.isEmpty) return "Unknown";
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  String _getAvatarPath(Zone zone) {
    var tag = zone.dangerTag ?? 'Other';
    var id = zone.userId;
    if (tag == 'Natural Hazard') tag = 'hazard';
    return id == 'AI'
        ? 'assets/avatars/prediction.png'
        : 'assets/avatars/${tag.toLowerCase()}_near.png';
  }
}
