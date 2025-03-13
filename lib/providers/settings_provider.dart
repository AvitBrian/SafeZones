import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _alertRadiusKey = 'alert_radius';
  static const String _soundAlertsKey = 'sound_alerts';
  static const String _emergencyContactKey = 'emergency_contact';
  
  bool _locationTracking = true;
  double _alertRadius = 300;
  bool _soundAlertsEnabled = true;
  String _emergencyContact = '';

  bool get locationTracking => _locationTracking;
  double get alertRadius => _alertRadius;
  bool get soundAlertsEnabled => _soundAlertsEnabled;
  String get emergencyContact => _emergencyContact;

  SettingsProvider() {
    _loadSettings();
    _checkLocationPermission();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _alertRadius = prefs.getDouble(_alertRadiusKey) ?? 300;
    _soundAlertsEnabled = prefs.getBool(_soundAlertsKey) ?? true;
    _emergencyContact = prefs.getString(_emergencyContactKey) ?? '';
    notifyListeners();
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

  Future<void> setAlertRadius(double value) async {
    _alertRadius = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_alertRadiusKey, value);
    notifyListeners();
  }

  Future<void> setSoundAlertsEnabled(bool value) async {
    _soundAlertsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundAlertsKey, value);
    notifyListeners();
  }

  Future<void> setEmergencyContact(String contact) async {
    _emergencyContact = contact;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emergencyContactKey, contact);
    notifyListeners();
  }
}
