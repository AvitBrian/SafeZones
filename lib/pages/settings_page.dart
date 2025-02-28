import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../providers/settings_provider.dart';
import '../screens/auth_screen.dart';
import '../utils/next_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: MyConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(color: MyConstants.titleColor),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text(
              "Location",
              style: theme.textTheme.titleMedium?.copyWith(
                color: MyConstants.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text("Real-time tracking",
              style:TextStyle(color:  MyConstants.subtextColor),),
              value: settings.locationTracking,
              onChanged: (value) async {
                await settings.setLocationTracking(value);
              },
              activeColor: Colors.deepPurple,
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "Alerts",
              style: theme.textTheme.titleMedium?.copyWith(
                color: MyConstants.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text("Alert Radius",
                    style:TextStyle(color:  MyConstants.subtextColor),),
                  subtitle: Text("${settings.alertRadius.round()} meters",
    style:TextStyle(color:  MyConstants.subtextColor),),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.deepPurple,
                      inactiveTrackColor: Colors.deepPurple.withOpacity(0.2),
                      thumbColor: Colors.deepPurple,
                      overlayColor: Colors.deepPurple.withOpacity(0.1),
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
                  title:  Text("Alerts",
                    style:TextStyle(color:  MyConstants.subtextColor),),
                  value: settings.soundAlertsEnabled,
                  onChanged: (value) {
                    settings.setSoundAlertsEnabled(value);
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              "App",
              style: theme.textTheme.titleMedium?.copyWith(
                color: MyConstants.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text("Privacy",
                    style:TextStyle(color:  MyConstants.subtextColor),),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to privacy page
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title:  Text("About",
                    style:TextStyle(color:  MyConstants.subtextColor),),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to about page
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.white,
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

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Account"),
          content: const Text(
            "Are you sure you want to delete your account? This action cannot be undone.",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                nextScreenReplacement(context, const AuthScreen());
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}