import 'package:flutter/material.dart';

class MyConstants {
  // Screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  // Screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
  
  // Get colors based on dark mode setting
  static Color getBackgroundColor(bool darkMode) => 
      darkMode ? const Color.fromARGB(255, 1, 12, 19) : Colors.white;
  
  static Color getTilesColor(bool darkMode) => 
      darkMode ? const Color.fromARGB(255, 29, 41, 66) : Colors.grey.shade100;
  
  static Color getTextColor(bool darkMode) => 
      darkMode ? Colors.white : Colors.black87;
  
  static Color getSubtextColor(bool darkMode) => 
      darkMode ? Colors.white70 : Colors.black54;
  
  static Color getHintTextColor(bool darkMode) => 
      darkMode ? Colors.grey.shade500 : Colors.grey.shade600;

  // Fixed colors that don't change with theme
  static Color titleColor = Colors.white;
  static Color primaryColor = const Color.fromARGB(255, 32, 46, 128);
  static Color secondaryColor = const Color.fromARGB(255, 17, 8, 99);
  static Color navColor = Colors.grey.shade200;
  
  // Legacy color properties (for backward compatibility)
  static Color backgroundColor = const Color.fromARGB(255, 1, 12, 19);
  static Color tilesColor = const Color.fromARGB(255, 29, 41, 66);
  static Color textColor = Colors.white;
  static Color subtextColor = Colors.white70;
  static Color hintText = Colors.grey.shade500;
  
  static BorderRadiusGeometry roundness = BorderRadius.circular(16);
}
