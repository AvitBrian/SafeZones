import 'package:flutter/material.dart';
import 'package:safezones/utils/constants.dart';

class MyExpandableTextField extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final int? height;

  const MyExpandableTextField({
    super.key,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    double width = MyConstants.screenWidth(context);
    double height = MyConstants.screenHeight(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.005),
      child: TextFormField(
        minLines: null,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white),
              borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(15)),
          fillColor: Colors.grey.shade200,
          filled: true,
        ),
        controller: controller,
        obscureText: obscureText,
      ),
    );
  }
}
