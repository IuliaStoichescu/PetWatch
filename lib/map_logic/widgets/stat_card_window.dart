import 'package:flutter/material.dart';
import 'package:pet_watch/map_logic/widgets/stat_card.dart';

class StatCardWindow extends StatelessWidget {
  final double totalDistance; // in meters
  final String formattedDuration;
  StatCardWindow({super.key,required this.totalDistance,required this.formattedDuration});

  @override
  Widget build(BuildContext context) {
    return  Positioned(
            top: 30,
            left: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StatCard(
                        title: "Distance",
                        value:
                            "${(totalDistance / 1000).toStringAsFixed(2)} km",
                        icon: Icons.map,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 10), // spacing between cards
                      StatCard(
                        title: "Time Out",
                        value: formattedDuration,
                        icon: Icons.timer,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }
}