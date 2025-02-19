import 'package:flutter/material.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Stack(
      fit: StackFit.expand, 
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/second.png"),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        Align(
            alignment: Alignment.center, // Moves the dog image to the right
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100), // Adjust position
              child: SizedBox(
                width: 300, // Increased width
                height: 300, // Increased height
                child: Image.asset(
                  "assets/map.png",
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