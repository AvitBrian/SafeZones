import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/screens/map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Components/button.dart';
import '../Components/textfield.dart';
import '../services/auth_service.dart';
import '../providers/connection_provider.dart';
import '../utils/constants.dart';
import '../utils/next_screen.dart';
import '../utils/snack_bar.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthService>();
    final connProvider = context.read<ConnectionProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    Future<void> handleSignUp() async {
      if (!_formKey.currentState!.validate()) return;

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();
      final location = _locationController.text.trim();

      if (!connProvider.hasInternet) {
        openSnackBar(context, "No internet connection", Colors.red);
        return;
      }

      final user = await authProvider.signUpWithEmail(email, password);
      if (user != null) {
        /// save data to firestore
        final success = await authProvider.saveUserData(
          user,
          location,
          '',
          createdAt: Timestamp.now(),
        );

        if (success) {
          await user.firebaseUser?.sendEmailVerification();
          handleAfterSignUp();
        } else {
          openSnackBar(context, "Failed to save user data", Colors.red);
        }
      } else {
        openSnackBar(context, authProvider.errorMessage ?? "Sign up failed", Colors.red);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "How are you today?",
                        style: TextStyle(
                          color: MyConstants.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
                      Text(
                        "Let's sign you up,",
                        style: TextStyle(
                          color: MyConstants.textColor,
                          fontSize: 16,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
                MyTextField(
                  hintText: "Username",
                  icon: const Icon(Icons.person_2_outlined),
                  controller: _usernameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a username';
                    if (value.length < 3) return 'Username must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),
                MyTextField(
                  hintText: "Email",
                  icon: const Icon(Icons.email_outlined),
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter an email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),
                MyTextField(
                  hintText: "Location",
                  icon: const Icon(Icons.location_on_outlined),
                  controller: _locationController,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your location';
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),
                MyTextField(
                  hintText: "Password",
                  icon: const Icon(Icons.lock_outline),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8.0),
                MyTextField(
                  hintText: "Confirm Password",
                  icon: const Icon(Icons.lock_outline),
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),
                Stack(
                  children: [
                    MyButton(
                      label: "Sign Up",
                      onTap: handleSignUp,
                      width: screenWidth,
                      height: 60,
                    ),
                    if (authProvider.isLoading)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: MyConstants.secondaryColor,
                        ),
                        height: 76,
                        width: screenWidth,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.amber,
                            strokeWidth: 5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void handleAfterSignUp() {
    nextScreen(context, const MapScreen());
  }
}
