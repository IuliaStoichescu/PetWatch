import 'package:flutter/material.dart';

class ThirdPage extends StatelessWidget {
  const ThirdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Stack(
      fit: StackFit.expand, 
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/third.png"),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        Align(
            alignment: Alignment.center, // Moves the dog image to the right
            child: Padding(
              padding: const EdgeInsets.only(bottom: 200), // Adjust position
              child: SizedBox(
                width: 400, // Increased width
                height: 400, // Increased height
                child: Image.asset(
                  "assets/orange-cat.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: 400,)
      ],
    ),
  );  
  }
}