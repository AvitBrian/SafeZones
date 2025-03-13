import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/screens/auth_screen.dart';
import 'package:safezones/utils/constants.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/next_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthService>();
    final user = authProvider.currentUser;
    final userData = authProvider.userData;
    String userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: MyConstants.backgroundColor,
      appBar: AppBar(
        title: Text("Profile", style: TextStyle(color: MyConstants.titleColor)),
        centerTitle: true,
        backgroundColor: MyConstants.primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: userData?.profileImageUrl != null
                    ? NetworkImage(userData!.profileImageUrl)
                    : user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: userData?.profileImageUrl == null && user?.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                userData?.username ?? user?.displayName ?? "User",
                style: TextStyle(
                  fontSize: 24,
                  color: MyConstants.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userData?.email ?? user?.email ?? "@user",
                style: TextStyle(
                  fontSize: 16,
                  color: MyConstants.subtextColor,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _updateLocation(context, authProvider),
                child: Text(
                  userData?.location.isNotEmpty == true ? userData!.location : "Set Location",
                  style: TextStyle(
                    fontSize: 16,
                    color: MyConstants.subtextColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      "Safety Stats",
                      style: TextStyle(
                        fontSize: 20,
                        color: MyConstants.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<int>(
                      future: FirestoreService().countUserFlags(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        int flagCount = snapshot.data ?? 0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem("Flags Raised", flagCount.toString()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: MyConstants.screenHeight(context) * .30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _signOut(context, authProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Sign Out",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: MyConstants.primaryColor,fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _signOut(BuildContext context, AuthService authProvider) {
    authProvider.signOut();
    Future.delayed(const Duration(milliseconds: 500)).then((value) {
      nextScreenReplacement(context, const AuthScreen());
    });
  }

  void _updateLocation(BuildContext context, AuthService authProvider) {
    TextEditingController locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Location"),
          content: TextField(
            controller: locationController,
            decoration: const InputDecoration(hintText: "Enter new location"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String newLocation = locationController.text.trim();
                if (newLocation.isNotEmpty) {
                  authProvider.updateUserLocation(newLocation);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Update"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }
}
