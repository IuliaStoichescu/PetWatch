import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.teal, Colors.teal],
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
            title: const Text("Help", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              "💡 I'm Home Button",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
                    "• The \"I'm Home\" button should be pressed once your pet is safely back home.\n"
                    "• This action will stop the out-of-home timer and record the total time spent outside.\n"
                    "• You can track your pet’s journey and total distance using the live map.",
                    style: TextStyle(fontSize: 15),
                  ),
            SizedBox(height: 24),
            Text(
              "📍 Map Controls",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "• Use the + and - buttons to zoom in and out.\n"
              "• Tap on the location icon to place geofences.\n"
              "• The location icon centers the map on your pet or home.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Text(
              "🎯 Follow Mode",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "• Follow Mode automatically keeps the camera centered on your pet's location in real-time.\n"
              "• To enable it, tap the eye icon \n"
              "• This helps you monitor your pet’s movements without manually adjusting the map.\n"
              "• Tap the icon again to exit this mode",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Text(
              "🔔 Notifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "You'll receive alerts based on your pet’s activity, location, and sensor data (like falling or high impact).",
              style: TextStyle(fontSize: 16),
            ),
                        SizedBox(height: 24),
            Text(
              "📶 Connectivity Logic",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "The app decides the best connection strategy based on internet availability:\n",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "• ✅ *Cloud MQTT* is used when both the phone and ESP32 Gateway device are connected to the internet.\n"
              "• 🌐 *Local WebSocket* is used when neither the phone nor the ESP Gateway has internet, and they are on the same WiFi (AP mode).\n"
              "• ⚠️ If only one device has internet, GPS data cannot be transmitted.\n"
              "• 🔄 Connect to Wifi Access Point: WIFI: ESP32_Pet_Tracker, PASSWORD: 9876543210",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              "Tip: If ESP32 Gateway is not online , connect your phone to the ESP hotspot for local fallback.",
              style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
