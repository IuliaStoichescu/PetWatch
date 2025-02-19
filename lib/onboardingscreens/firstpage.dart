import 'package:flutter/material.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Stack(
      fit: StackFit.expand, 
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/first.png"),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        Align(
            alignment: Alignment.topRight, // Moves the dog image to the right
            child: Padding(
              padding: const EdgeInsets.only(left: 100), // Adjust position
              child: SizedBox(
                width: 800, // Increased width
                height: 800, // Increased height
                child: Image.asset(
                  "assets/dog.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    ),
  );  
  }
}
//