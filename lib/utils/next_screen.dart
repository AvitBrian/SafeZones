import 'package:flutter/material.dart';

void nextScreen(context, screen) {
  Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
}

void nextScreenReplacement(context, screen) {
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => screen));
}
