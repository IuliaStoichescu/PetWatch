import 'package:flutter/material.dart';

class NotificationPopup extends StatelessWidget {
  final String title;
  final String body;
  final String imageUrl;
  final String time;

  const NotificationPopup({
    super.key,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Image.network(imageUrl, height: 100),
          SizedBox(height: 10),
          Text(body),
          SizedBox(height: 10),
          Text("⏰ $time", style: TextStyle(color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(
          child: Text("Close"),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }
}
