import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/map_logic/services/custom-notification.dart';

class NotificationListPage extends StatelessWidget {
  final List<CustomNotification> notifications;

  const NotificationListPage({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
  preferredSize: Size.fromHeight(60),
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.pink,
          Colors.pink,
          ui.Color.fromARGB(255, 244, 116, 186),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          spreadRadius: 2,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      title: Text(
        "Activity Log",
        style: TextStyle(color: Colors.white),
      ),
      automaticallyImplyLeading: true,
    ),
  ),
),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("No activity yet.", style: TextStyle(fontSize: 18)),
                  Lottie.asset('assets/no_activity.json'),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];

                return Container(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.pinkAccent,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notif.body,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        notif.time,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
