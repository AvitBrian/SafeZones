import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: MyConstants.primaryColor,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/texts/privacy_policy.txt'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load privacy policy'));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              child: Text(
                snapshot.data != null
                    ? '\n${snapshot.data}'
                    : 'No privacy policy available',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: MyConstants.getTextColor(
                      Theme.of(context).brightness == Brightness.dark),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
