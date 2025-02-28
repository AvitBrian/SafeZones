import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/screens/auth_screen.dart';
import 'package:safezones/utils/constants.dart';
import '../services/auth_service.dart';
import '../utils/next_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthService>();
    final user = authProvider.currentUser;
    final userData = authProvider.userData;

    return Scaffold(
      backgroundColor: MyConstants.backgroundColor,
      appBar: AppBar(
        title: Text("Profile", style: TextStyle(color: MyConstants.titleColor)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
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
              Text(
                userData?.location ?? "Location not set",
                style: TextStyle(
                  fontSize: 16,
                  color: MyConstants.subtextColor,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem("Flags Raised", userData?.flags?.length.toString() ?? "0"),
                      ],
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: MyConstants.subtextColor,
          ),
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
}
