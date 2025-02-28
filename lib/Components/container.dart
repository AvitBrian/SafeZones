import 'package:flutter/material.dart';
import 'package:safezones/utils/constants.dart';

class MyContainer extends StatelessWidget {
  final String? image;
  final double? height;
  final double? width;
  final Color color;
  final Color? fill;
  const MyContainer(
      {super.key, this.image, this.width, this.height, required this.color, this.fill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          color: fill ?? Colors.white.withOpacity(.5)),
      child: Image.asset(
        image!,
        height: height,
        width: width,
      ),
    );
  }
}
