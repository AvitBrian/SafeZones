import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _alertRadiusKey = 'alert_radius';
  static const String _soundAlertsKey = 'sound_alerts';
  static const String _emergencyContactKey = 'emergency_contact';
  static const String _darkModeKey = 'dark_mode';
  static const String _showAiPredictionsKey = 'show_ai_predictions';
  static const String _userConsentKey = 'user_consent';

  bool _darkMode = true;
  bool _locationTracking = true;
  double _alertRadius = 300;
  bool _soundAlertsEnabled = true;
  String _emergencyContact = '';
  bool _showAiPredictions = true;
  bool _userConsent = false;

  bool get locationTracking => _locationTracking;

  double get alertRadius => _alertRadius;

  bool get soundAlertsEnabled => _soundAlertsEnabled;

  String get emergencyContact => _emergencyContact;

  bool get darkMode => _darkMode;

  bool get showAiPredictions => _showAiPredictions;

  bool get userConsent => _userConsent;

  SettingsProvider() {
    _loadSettings();
    _checkLocationPermission();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _userConsent = prefs.getBool(_userConsentKey) ?? false;
    _alertRadius = prefs.getDouble(_alertRadiusKey) ?? 300;
    _soundAlertsEnabled = prefs.getBool(_soundAlertsKey) ?? true;
    _emergencyContact = prefs.getString(_emergencyContactKey) ?? '';
    _darkMode = prefs.getBool(_darkModeKey) ?? true;
    _showAiPredictions = prefs.getBool(_showAiPredictionsKey) ?? true;
    notifyListeners();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    _locationTracking = status.isGranted;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
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

  Future<void> toggleAiPredictions() async {
    _showAiPredictions = !_showAiPredictions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAiPredictionsKey, _showAiPredictions);
    notifyListeners();
  }

  Future<void> setShowAiPredictions(bool value) async {
    _showAiPredictions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAiPredictionsKey, value);
    notifyListeners();
  }

  Future<void> setUserConsent(bool value) async {
    _userConsent = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userConsentKey, value);
    notifyListeners();
  }
}
