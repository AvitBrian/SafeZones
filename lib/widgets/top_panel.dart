import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import 'package:safezones/providers/map_provider.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../utils/next_screen.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with SingleTickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Original TopBar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Settings Icon
              GestureDetector(
                onTap: () {
                  // Navigate to the Settings Page
                  nextScreen(context, const SettingsPage());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.settings, color: MyConstants.primaryColor),
                ),
              ),
              // App Logo and Title
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Image.asset(
                      "assets/images/logo.png",
                      height: 60,
                      width: 60,
                    ),
                  ],
                ),
              ),
              // Profile Icon
              GestureDetector(
                onTap: () {
                  nextScreen(context, const ProfilePage());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.person_2_rounded, color: MyConstants.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}