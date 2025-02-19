import 'package:flutter/material.dart';

class Mytextfield extends StatelessWidget {
  final controller;
  final String hintText;
  final Icon prefixIcon;
  final bool obscureText;

  const Mytextfield({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: TextField(
        cursorColor: Color(0xFF73BDF3),
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: const Color.fromARGB(201, 255, 255, 255))
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white)
          ),
          fillColor: const Color.fromARGB(91, 255, 253, 253),
          filled: true,
          prefixIcon: prefixIcon,
          hintText: hintText,
          hintStyle: TextStyle(color: const Color.fromARGB(255, 255, 255, 255)),
          focusColor: Colors.white,
        ),
      ),
    );
  }
}