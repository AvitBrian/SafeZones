import 'package:flutter/material.dart';

class MyConstants {
  // Screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  // Screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
  static Color titleColor = Colors.white;
  // Primary color
  static Color primaryColor = Colors.deepPurple;

  // Secondary color (teal)
  static Color secondaryColor = Colors.purple.shade100;

  // Background color
  static Color backgroundColor = Colors.deepPurple.shade50;
  static Color navColor = Colors.grey.shade200;
  // text color
  static Color textColor = Colors.black;
  static Color subtextColor= Colors.black54;
  static Color hintText = Colors.grey.shade500;
}
