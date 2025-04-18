import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safezones/screens/map_screen.dart';

import '../Components/button.dart';
import '../Components/container.dart';
import '../Components/terms_sheet.dart';
import '../Components/textfield.dart';
import '../services/auth_service.dart';
import '../providers/connection_provider.dart';
import '../utils/constants.dart';
import '../utils/next_screen.dart';
import '../utils/snack_bar.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm>
    with SingleTickerProviderStateMixin {
  bool _isLoadingGoogle = false;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  late final AnimationController _controller;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleEmailAndPasswordSignIn() async {
    final authProvider = context.read<AuthService>();
    authProvider.clearError();

    if (!_acceptedTerms) {
      openSnackBar(context, "Please accept both agreements", Colors.orange);
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      openSnackBar(context, "Please fill in all fields", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await authProvider.signInWithEmail(email, password);
      if (user != null) {
        handleAfterLogin();
      } else {
        openSnackBar(
            context, authProvider.errorMessage ?? "Sign in failed", Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> handleGoogleSignIn() async {
    final authProvider = context.read<AuthService>();
    authProvider.clearError();

    if (!_acceptedTerms) {
      openSnackBar(context, "Please accept both agreements", Colors.orange);
      return;
    }

    setState(() => _isLoadingGoogle = true);

    try {
      final user = await authProvider.signInWithGoogle();
      if (user != null) {
        handleAfterLogin();
      } else {
        if (authProvider.errorMessage != null) {
          openSnackBar(context, authProvider.errorMessage!, Colors.red);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGoogle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          SizedBox(
            height: 135,
            child: Image.asset(
              'assets/images/logo-long.png',
              height: 90,
              width: screenWidth * .8,
              fit: BoxFit.fitWidth,
            ),
          ),
          SizedBox(height: screenHeight * .05),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hi there!",
                  style: TextStyle(
                      color: MyConstants.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 40),
                ),
                const SizedBox(height: 2),
                Text(
                  "Welcome Back, you've been missed...",
                  style: TextStyle(color: MyConstants.textColor),
                ),
                Text(
                  'Sign in to continue',
                  style: TextStyle(color: MyConstants.textColor),
                )
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          MyTextField(
            hintText: "Email",
            icon: Icon(
              Icons.email_outlined,
              color: MyConstants.primaryColor,
            ),
            controller: emailController,
          ),
          const SizedBox(height: 16.0),
          MyTextField(
            hintText: "Password",
            icon: Icon(
              Icons.lock_outline,
              color: MyConstants.primaryColor,
            ),
            controller: passwordController,
            obscureText: true,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  overlayColor: MyConstants.primaryColor.withValues(alpha: 0.6),
                ),
                child: Text(
                  "forgot password?",
                  style:
                      TextStyle(color: MyConstants.primaryColor.withBlue(180)),
                ),
              ),
            ],
          ),
          Column(children: [
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  activeColor: MyConstants.primaryColor.withValues(alpha: .9),
                  checkColor: Colors.amberAccent,
                  onChanged: (value) =>
                      setState(() => _acceptedTerms = value ?? false),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => TermsSheet.show(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: 'I agree to the ',
                        style: TextStyle(color: MyConstants.textColor),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: MyConstants.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),
          Stack(
            children: [
              MyButton(
                label: "Sign In",
                onTap: handleEmailAndPasswordSignIn,
                width: screenWidth * .88,
                height: 60,
              ),
              Visibility(
                visible: _isLoading,
                child: Container(
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
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Divider(
                  thickness: 0.5,
                  color: MyConstants.primaryColor.withValues(alpha: 0.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "or Sign in with",
                  style: TextStyle(
                      color: MyConstants.subtextColor..withValues(alpha: 0.3)),
                ),
              ),
              Expanded(
                child: Divider(
                  thickness: 0.5,
                  color: MyConstants.primaryColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: handleGoogleSignIn,
                    child: MyContainer(
                      image: "assets/images/google.png",
                      height: 40,
                      width: screenWidth * .83,
                      fill: MyConstants.primaryColor.withAlpha(20),
                      color: MyConstants.primaryColor.withAlpha(120),
                    ),
                  ),
                  Visibility(
                    visible: _isLoadingGoogle,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: MyConstants.primaryColor.withValues(alpha: 0.5),
                      ),
                      height: 59,
                      width: screenWidth * .88,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.amber,
                          strokeWidth: 5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void handleAfterLogin() async {
    if (!mounted) return;
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      nextScreenReplacement(context, const MapScreen());
    } catch (e) {
      if (!mounted) return;
      openSnackBar(context, "An error occurred", Colors.red);
    }
  }
}
