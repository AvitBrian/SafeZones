import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsProvider extends ChangeNotifier {
  bool _locationTracking = true;
  double _alertRadius = 300;
  bool _soundAlertsEnabled = true;

  bool get locationTracking => _locationTracking;
  double get alertRadius => _alertRadius;
  bool get soundAlertsEnabled => _soundAlertsEnabled;

  SettingsProvider() {
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    _locationTracking = status.isGranted;
    notifyListeners();
  }

  Future<void> setLocationTracking(bool value) async {
    if (value && !_locationTracking) {
      final status = await Permission.location.request();
      _locationTracking = status.isGranted;
    } else {
      _locationTracking = value;
    }
    notifyListeners();
  }

  void setAlertRadius(double value) {
    _alertRadius = value;
    notifyListeners();
  }

  void setSoundAlertsEnabled(bool value) {
    _soundAlertsEnabled = value;
    notifyListeners();
  }
}
