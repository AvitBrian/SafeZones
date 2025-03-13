import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../pages/sign_in.dart';
import '../pages/sign_up.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: MyConstants.backgroundColor,
      systemNavigationBarColor: MyConstants.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: MyConstants.backgroundColor,
      body: SafeArea(
        child: SizedBox(
          height: MyConstants.screenHeight(context),
          width: MyConstants.screenWidth(context),
          child: Column(
            children: [
              Expanded(
                flex: 10,
                child: SizedBox(
                  width: MyConstants.screenWidth(context),
                  child: SingleChildScrollView(
                    child: authService.showSignIn
                        ? const SignInForm()
                        : const SignUpForm(),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.bottomCenter,
                  width: MyConstants.screenWidth(context),
                  child: authService.showSignIn
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Not a Member?",
                              style: TextStyle(color: MyConstants.subtextColor),
                            ),
                            TextButton(
                              onPressed: authService.toggleAuthState,
                              style: ButtonStyle(
                                overlayColor:
                                    WidgetStateProperty.all(Colors.transparent),
                              ),
                              child: Text(
                                "Register",
                                style: TextStyle(
                                    color: MyConstants.primaryColor
                                        .withAlpha(250)),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already a member?",
                              style: TextStyle(color: MyConstants.subtextColor),
                            ),
                            TextButton(
                              onPressed: authService.toggleAuthState,
                              style: ButtonStyle(
                                overlayColor:
                                    WidgetStateProperty.all(Colors.transparent),
                              ),
                              child: Text(
                                "Log in",
                                style: TextStyle(
                                    color: MyConstants.primaryColor
                                        .withAlpha(250)),
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
    );
  }
}
