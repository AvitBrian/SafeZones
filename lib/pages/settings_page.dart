import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/pages/privacy_policy_page.dart';
import 'package:safezones/utils/constants.dart';
import '../providers/settings_provider.dart';
import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/next_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.darkMode) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final backgroundColor = MyConstants.getBackgroundColor(settings.darkMode);
    final textColor = MyConstants.getTextColor(settings.darkMode);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(color: MyConstants.titleColor),
        ),
        centerTitle: true,
        backgroundColor: MyConstants.primaryColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text("Appearance",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Card(
            elevation: 0,
            color: MyConstants.getTilesColor(settings.darkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              onTap: () {
                if (settings.darkMode) {
                  _animationController.reverse();
                } else {
                  _animationController.forward();
                }
                settings.setDarkMode(!settings.darkMode);
              },
              child: ListTile(
                title: Text(
                  "Dark Mode",
                  style: TextStyle(
                      color: MyConstants.getSubtextColor(settings.darkMode)),
                ),
                trailing: GestureDetector(
                  onTap: () {
                    if (settings.darkMode) {
                      _animationController.reverse();
                    } else {
                      _animationController.forward();
                    }
                    settings.setDarkMode(!settings.darkMode);
                  },
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value * 2 * 3.14159,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 1 - _animationController.value,
                              child: const Icon(
                                Icons.wb_sunny,
                                color: Colors.amber,
                                size: 24,
                              ),
                            ),
                            Opacity(
                              opacity: _animationController.value,
                              child: const Icon(
                                Icons.nightlight_round,
                                color: Colors.indigo,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "Location",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyConstants.getTextColor(settings.darkMode),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            color: MyConstants.getTilesColor(settings.darkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                "Real-time tracking",
                style: TextStyle(
                    color: MyConstants.getSubtextColor(settings.darkMode)),
              ),
              value: settings.locationTracking,
              onChanged: (value) async {
                await settings.setLocationTracking(value);
              },
              activeColor: MyConstants.primaryColor.withBlue(200),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "AI Predictions",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyConstants.getTextColor(settings.darkMode),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            color: MyConstants.getTilesColor(settings.darkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                "Show AI Predictions",
                style: TextStyle(
                    color: MyConstants.getSubtextColor(settings.darkMode)),
              ),
              value: settings.showAiPredictions,
              onChanged: (value) async {
                await settings.setShowAiPredictions(value);
              },
              activeColor: MyConstants.primaryColor.withBlue(200),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "Alerts",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyConstants.getTextColor(settings.darkMode),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            color: MyConstants.getTilesColor(settings.darkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    "Alert Radius",
                    style: TextStyle(
                        color: MyConstants.getSubtextColor(settings.darkMode)),
                  ),
                  subtitle: Text(
                    "${settings.alertRadius.round()} meters",
                    style: TextStyle(
                        color: MyConstants.getSubtextColor(settings.darkMode)),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: MyConstants.primaryColor,
                      inactiveTrackColor:
                          MyConstants.primaryColor.withValues(alpha: 0.2),
                      thumbColor: MyConstants.primaryColor,
                      overlayColor:
                          MyConstants.primaryColor.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: settings.alertRadius,
                      min: 5,
                      max: 1000,
                      divisions: 18,
                      onChanged: (value) {
                        settings.setAlertRadius(value);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    "Alerts",
                    style: TextStyle(
                        color: MyConstants.getSubtextColor(settings.darkMode)),
                  ),
                  value: settings.soundAlertsEnabled,
                  onChanged: (value) {
                    settings.setSoundAlertsEnabled(value);
                  },
                  activeColor: MyConstants.primaryColor.withBlue(200),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "App",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MyConstants.getTextColor(settings.darkMode),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            elevation: 0,
            color: MyConstants.getTilesColor(settings.darkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    "Privacy",
                    style: TextStyle(
                        color: MyConstants.getSubtextColor(settings.darkMode)),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: MyConstants.primaryColor,
                  ),
                  onTap: () => nextScreen(context, const PrivacyPolicyPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: Colors.red.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text(
                "Delete Account",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = FirestoreService();
    final userId = authService.currentUser?.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MyConstants.primaryColor,
        title: Text(
          "Delete Account",
          style: TextStyle(color: MyConstants.textColor),
        ),
        content: Text(
          "Are you sure you want to delete your account? This action cannot be undone.",
          style: TextStyle(color: MyConstants.subtextColor),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (userId != null) {
                await firestoreService.deleteUserFlags(userId);
                await authService.deleteAccount();
              }
              nextScreenReplacement(context, const AuthScreen());
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactDialog(
      BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.emergencyContact);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MyConstants.primaryColor,
        title: Text(
          'Set Emergency Contact',
          style: TextStyle(color: MyConstants.textColor),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: .5),
            labelText: 'Phone Number',
            labelStyle: TextStyle(color: MyConstants.subtextColor),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.deepOrangeAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              settings.setEmergencyContact(controller.text);
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
