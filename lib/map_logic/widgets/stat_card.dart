import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  String title;
  String value;
  IconData icon;
  Color color;
  StatCard({super.key,required this.title,required this.value,required this.icon,required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,color: color,size: 30,),
        SizedBox(height: 5,),
        Text(value,style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),),
        SizedBox(height: 5,),
        Text(title,style: TextStyle(fontSize: 16,color: Colors.grey),),
      ],
    );
  }
}