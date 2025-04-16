import 'package:flutter/material.dart';

class WeatherInfoBox extends StatelessWidget {
  final Map<String, dynamic> weatherData;

  const WeatherInfoBox({super.key, required this.weatherData});

  @override
  Widget build(BuildContext context) {
    final current = weatherData['current'];
    final iconUrl = "https:${current['condition']['icon']}";
    final temperature = "${current['temp_c']}°C";
    final condition = current['condition']['text'];

    return Positioned(
      top: 30,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              iconUrl,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.cloud_off),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temperature,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  condition,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
