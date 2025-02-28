import 'package:flutter/material.dart';
import 'package:safezones/utils/constants.dart';

class MyTextField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final BorderRadius? roundness;
  final Icon? icon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;

  const MyTextField({
    super.key,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.roundness,
    this.icon,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MyConstants.screenWidth(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.005),
      child: TextFormField(
        style: TextStyle(color: MyConstants.textColor),
        decoration: InputDecoration(
          prefixIcon: icon,
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: TextStyle(color: MyConstants.hintText),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: MyConstants.subtextColor.withOpacity(.1)),
            borderRadius: roundness ?? BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: roundness ?? BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: roundness ?? BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: roundness ?? BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          fillColor: Colors.grey.shade200,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 12.0,
          ),
        ),
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
      ),
    );
  }
}