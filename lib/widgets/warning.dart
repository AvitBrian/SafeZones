import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:safezones/providers/settings_provider.dart';
import 'package:safezones/providers/map_provider.dart';
import 'package:safezones/models/zone_model.dart' as custom;

class WarningNotification extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onSnooze;

  const WarningNotification.notify({
    super.key,
    required this.message,
    this.color = Colors.red,
    this.onTap,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(message),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        onSnooze?.call();
      },
      background: Container(color: Colors.transparent),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              GestureDetector(
                onTap: onSnooze,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Snooze',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationManager {
  static OverlayEntry? _currentNotification;
  static Timer? _snoozeTimer;
  static final Map<String, DateTime> _snoozedNotifications = {};
  static const int _snoozeMinutes = 3;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static bool get isShowing => _currentNotification != null;

  static void show(
    BuildContext context, {
    required String message,
    Color color = Colors.red,
    required String zoneId,
    VoidCallback? onSnooze,
  }) {
    if (_snoozedNotifications.containsKey(zoneId)) {
      DateTime snoozeEndTime = _snoozedNotifications[zoneId]!;
      if (DateTime.now().isBefore(snoozeEndTime)) {
        return;
      } else {
        _snoozedNotifications.remove(zoneId);
      }
    }

    _currentNotification?.remove();

    if (SettingsProvider().soundAlertsEnabled) {
      _audioPlayer.play(AssetSource('sounds/beep.mp3'));
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
    }

    void snoozeAction() {
      _audioPlayer.stop();
      hide();

      _snoozedNotifications[zoneId] =
          DateTime.now().add(const Duration(minutes: _snoozeMinutes));

      _snoozeTimer?.cancel();
      _snoozeTimer = Timer(const Duration(minutes: _snoozeMinutes), () {
        if (_snoozedNotifications.containsKey(zoneId)) {
          _snoozedNotifications.remove(zoneId);
        }
      });

      onSnooze?.call();
    }

    _currentNotification = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 10,
              right: 10,
              child: WarningNotification.notify(
                message: message,
                color: color,
                onTap: () {
                  final mapProvider =
                      Provider.of<MapProvider>(context, listen: false);
                  final zone = mapProvider.zones.firstWhere(
                    (z) => z.id == zoneId,
                    orElse: () => custom.Zone(
                      id: '',
                      center: const LatLng(0, 0),
                      radius: 0,
                      dangerLevel: 0,
                      type: custom.ZoneType.flag,
                      count: 0,
                    ),
                  );
                  if (zone.id.isNotEmpty) {
                    mapProvider.centerOnZone(zone, custom.ZoneType.flag);
                  }
                },
                onSnooze: snoozeAction,
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_currentNotification!);
  }

  static void hide() {
    _audioPlayer.stop();
    _currentNotification?.remove();
    _currentNotification = null;
  }

  static void dispose() {
    hide();
    _snoozeTimer?.cancel();
    _snoozedNotifications.clear();
    _audioPlayer.dispose();
  }
}
