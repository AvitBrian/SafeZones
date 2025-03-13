import 'package:flutter/material.dart';
import 'package:safezones/utils/constants.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  height: 50,
                  decoration: BoxDecoration(
                    color: MyConstants.primaryColor,
                    borderRadius: MyConstants.roundness,
                  ),
                  child: const Icon(Icons.settings, color: Colors.white, size: 35,),
                ),
              ),

              GestureDetector(
                onTap: () {
                  nextScreen(context, const ProfilePage());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 50,
                  decoration: BoxDecoration(
                    color: MyConstants.primaryColor,
                    borderRadius: MyConstants.roundness,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 35,),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}