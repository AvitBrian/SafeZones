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
  static Color primaryColor = const Color.fromARGB(255, 32, 46, 128);

  // Secondary color (teal)
  static Color secondaryColor = const Color.fromARGB(255, 17, 8, 99);

  // Background color
  static Color backgroundColor = const Color.fromARGB(255, 1, 12, 19);
  static Color tilesColor = const Color.fromARGB(255, 29, 41, 66);
  static Color navColor = Colors.grey.shade200;

  // text color
  static Color textColor = Colors.white;
  static Color subtextColor = Colors.white70;
  static Color hintText = Colors.grey.shade500;
  static BorderRadiusGeometry roundness = BorderRadius.circular(12);
}
