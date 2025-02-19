import 'package:flutter/material.dart';

class SquareTile extends StatelessWidget {

  final String imagePath;
  final double imageSize;
  final double imageHeight;
  final Function()? onTap;
  const SquareTile({super.key,required this.imagePath, required this.imageSize,required this.imageHeight,required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          color: const Color.fromARGB(101, 229, 229, 229),
          borderRadius: BorderRadius.circular(16),
        ),
          child: Image.asset(
            imagePath,
            height: imageHeight,
            width: imageSize,
            ),
      ),
    );
  }
}