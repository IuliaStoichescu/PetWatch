import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {

  final Function()? onTap;
  final String text;
  const MyButton({super.key,required this.onTap,required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(horizontal: 150,vertical: 10),
        decoration: BoxDecoration(color:  Color.fromARGB(255, 44, 44, 44),
        borderRadius: BorderRadius.circular(10),
        /*boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 50, 25, 25), // ✅ Shadow color with opacity
          blurRadius: 3, // ✅ How much the shadow spreads
          spreadRadius: 2, // ✅ How much the shadow extends
          offset: Offset(0, 2), // ✅ Position: (X, Y)
        ),
      ],*/
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}