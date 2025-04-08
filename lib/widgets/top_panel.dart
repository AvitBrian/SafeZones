import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/utils/constants.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../utils/next_screen.dart';
import '../services/auth_service.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  /// Returns a greeting message and corresponding image path
  Map<String, String> _getGreetingAndImage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return {"greeting": "Good Morning", "image": "assets/images/morning.png"};
    }
    if (hour >= 12 && hour < 17) {
      return {
        "greeting": "Good Afternoon",
        "image": "assets/images/afternoon.png"
      };
    }
    if (hour >= 17 && hour < 21) {
      return {"greeting": "Good Evening", "image": "assets/images/evening.png"};
    }
    return {"greeting": "Good Night", "image": "assets/images/night.png"};
  }

  /// Extracts the first name from the full username
  String _getFirstName(String? username) {
    if (username == null || username.isEmpty) return " ";
    return username.split(" ").first;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthService>();
    final user = authProvider.currentUser;
    final userData = authProvider.userData;

    final greetingData = _getGreetingAndImage();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  nextScreen(context, const ProfilePage(),
                      transition: ScreenTransition.slideLeftToRight);
                },
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    height: 55,
                    decoration: BoxDecoration(
                      color: MyConstants.primaryColor,
                      borderRadius: MyConstants.roundness,
                      border: Border.all(
                          width: .9, color: MyConstants.secondaryColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          /// Profile Picture
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: userData?.profileImageUrl != null
                                ? NetworkImage(userData!.profileImageUrl)
                                : user?.photoURL != null
                                    ? NetworkImage(user!.photoURL!)
                                    : null,
                            child: userData?.profileImageUrl == null &&
                                    user?.photoURL == null
                                ? const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 35)
                                : null,
                          ),
                          const SizedBox(width: 5),

                          /// Greeting Text + Name + Icon
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                children: [
                                  Image.asset(
                                    greetingData["image"]!,
                                    height: 20,
                                    width: 20,
                                  ),
                                  const SizedBox(width: 5),

                                  /// Greeting Text
                                  Text.rich(
                                    TextSpan(
                                      text: "${greetingData["greeting"]}, ",
                                      style:
                                          const TextStyle(color: Colors.white),
                                      children: [
                                        /// User's First Name (Highlighted)
                                        TextSpan(
                                          text:
                                              _getFirstName(userData?.username),
                                          style: const TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                            text: "!",
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
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
                ),
              ),

              /// Settings Icon
              GestureDetector(
                onTap: () {
                  nextScreen(context, const SettingsPage());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  height: 55,
                  decoration: BoxDecoration(
                    color: MyConstants.primaryColor,
                    borderRadius: MyConstants.roundness,
                    border: Border.all(
                        width: .9, color: MyConstants.secondaryColor),
                  ),
                  child:
                      const Icon(Icons.settings, color: Colors.white, size: 35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
