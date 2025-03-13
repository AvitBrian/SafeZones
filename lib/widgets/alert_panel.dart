import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../models/zone_model.dart';
import '../providers/settings_provider.dart';
import '../providers/map_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/snack_bar.dart';

class AlertsPanel extends StatefulWidget {
  final Position? userLocation;
  final List<Zone> dangerZones;
  final Function(Zone zone)? onZoneSelected;
  final BitmapDescriptor? customPinIcon;

  const AlertsPanel({
    super.key,
    required this.userLocation,
    required this.dangerZones,
    this.onZoneSelected,
    this.customPinIcon,
  });

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Row(
        children: [

          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(

                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                backgroundColor:MyConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: MyConstants.roundness,
                      ),
                    ),
                    onPressed: () => _showDangerZonesPanel(context),
                    child: const FittedBox(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, color: Colors.white, size: 20),
                          SizedBox(width: 4),
                          Text('Alerts', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_getNearbyZones().isNotEmpty)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _getNearbyZones().length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: MyConstants.roundness,
                ),
              ),
              onPressed: () => _handleEmergency(context),
              child: const FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text('SOS', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEmergency(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.emergencyContact.isEmpty) {
      openSnackBar(
        context,
        'Please set an emergency contact in settings first',
        Colors.red,
      );
      return;
    }
    
    if (widget.userLocation != null) {
      String phoneNumber = settings.emergencyContact.replaceAll(RegExp(r'[^\d]'), '');
      if (!phoneNumber.startsWith('25')) {
        phoneNumber = phoneNumber.startsWith('0') ? '250${phoneNumber.substring(1)}' : '250$phoneNumber';
      }
      
      final message = "Hey, might be in danger! \n \nMy location: \nhttps://www.google.com/maps/search/?api=1&query=${widget.userLocation!.latitude},${widget.userLocation!.longitude}";
      final url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
      
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if(context.mounted) {
            openSnackBar(
            context,
            'WhatsApp is not installed',
            Colors.red,
          );
          }
        }
      } catch (e) {
        if(context.mounted){
          openSnackBar(
          context,
          'Error launching WhatsApp: $e',
          Colors.red,
        );}
      }
    }
  }

  void _showDangerZonesPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MyConstants.primaryColor.withValues(alpha: .5),
              borderRadius: MyConstants.roundness,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        "Nearby Alerts",
                        style: TextStyle(
                          color: MyConstants.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_getNearbyZones().length} active zones",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                SizedBox(
                  height: 300,
                  child: _getNearbyZones().isEmpty
                      ? _buildNoAlerts()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getNearbyZones().length,
                          itemBuilder: (context, index) {
                            final zone = _getNearbyZones()[index];
                            return _buildAlertItem(
                              zone.type == ZoneType.flag
                                  ? "Flagged Zone"
                                  : "Danger Zone",
                              "${(Geolocator.distanceBetween(
                                widget.userLocation!.latitude,
                                widget.userLocation!.longitude,
                                zone.center.latitude,
                                zone.center.longitude,
                              ) / 1000).toStringAsFixed(1)} km away",
                              zone.type == ZoneType.flag
                                  ? Colors.amber
                                  : Colors.redAccent,
                              onTap: () {
                                widget.onZoneSelected?.call(zone);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Zone> _getNearbyZones() {
    if (widget.userLocation == null) return [];
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    return widget.dangerZones.where((zone) {
      final distance = Geolocator.distanceBetween(
        widget.userLocation!.latitude,
        widget.userLocation!.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );
      return distance <= (settings.alertRadius + zone.radius);
    }).toList();
  }

  Widget _buildNoAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyConstants.secondaryColor,
        borderRadius: MyConstants.roundness,
      ),
      child: const Text(
        "No nearby danger zones detected.",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildAlertItem(String tag, String distance, Color severity,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          decoration: BoxDecoration(
            color: MyConstants.backgroundColor,
            borderRadius: MyConstants.roundness,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: severity, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                          color: MyConstants.textColor, fontSize: 16),
                    ),
                    Text(
                      distance,
                      style: TextStyle(
                          color: MyConstants.subtextColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
