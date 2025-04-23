import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // for pie and bar charts

class SessionAnalyticsPage extends StatefulWidget {
  final String petId;
  final Map<String, dynamic> currentSession;

  const SessionAnalyticsPage({
    required this.petId,
    required this.currentSession,
    Key? key,
  }) : super(key: key);

  @override
  State<SessionAnalyticsPage> createState() => _SessionAnalyticsPageState();
}

class _SessionAnalyticsPageState extends State<SessionAnalyticsPage> {
  final user = FirebaseAuth.instance.currentUser!;

  double maxDuration = 0;
  double maxDistance = 0;
  List<double> allDistances = [];
  double currentDuration = 0;
  double currentDistance = 0;
  double homeTimePercentage = 0;
  double outsideTimePercentage = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final sessions = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pets")
        .doc(widget.petId)
        .collection("pet_info")
        .doc("data")
        .collection("sessions")
        .get();

    double longest = 0;
    double longestDistance = 0;
    List<double> distances = [];

    for (var doc in sessions.docs) {
      final data = doc.data();
      final dur = data['duration_seconds']?.toDouble() ?? 0;
      final dist = data['distance_meters']?.toDouble() ?? 0;

      distances.add(dist);
      if (dur > longest) longest = dur;
      if (dist > longestDistance) longestDistance = dist;
    }

    setState(() {
      currentDuration = widget.currentSession['duration_seconds'].toDouble();
      currentDistance = widget.currentSession['distance_meters'].toDouble();
      maxDuration = longest;
      maxDistance = longestDistance;
      allDistances = distances;

      final locationData = widget.currentSession['path'] as List<dynamic>;
      int nearHome = 0;
      int away = 0;
      for (var point in locationData) {
        if (point['lat'] != null && point['lon'] != null) {
          // Assuming we mark home points specially or have them filtered
          final LatLng loc = LatLng(point['lat'], point['lon']);
          final bool isHome = widget.currentSession['home_zone']?.contains(loc.toString()) ?? false;
          if (isHome) {
            nearHome++;
          } else {
            away++;
          }
        }
      }
      final total = nearHome + away;
      homeTimePercentage = total > 0 ? nearHome / total * 100 : 0;
      outsideTimePercentage = total > 0 ? away / total * 100 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Session Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📊 Session Stats", style: Theme.of(context).textTheme.titleLarge),
            Divider(),
            SizedBox(height: 10),
            Text(
              currentDuration!=maxDuration?
            "⏱️ Duration: ${(100 - (currentDuration / maxDuration * 100)).toStringAsFixed(1)}% less than the longest session":
            "⏱️ This is your pets longest session!",
            style: TextStyle(fontSize: 16),
          ),
          Text(
            currentDistance!=maxDistance?
            "📏 Distance: ${(100 - (currentDistance / maxDistance * 100)).toStringAsFixed(1)}% less than the longest distance":
            "📏 This is your pets longest distance!",
            style: TextStyle(fontSize: 16),
          ),

            SizedBox(height: 20),

            Text("📍 Time Near Home vs Away",style: Theme.of(context).textTheme.titleLarge),
            Divider(),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: homeTimePercentage,
                      color: Colors.green,
                      title: "Home ${homeTimePercentage.toStringAsFixed(1)}%",
                    ),
                    PieChartSectionData(
                      value: outsideTimePercentage,
                      color: Colors.blue,
                      title: "Away ${outsideTimePercentage.toStringAsFixed(1)}%",
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Text("🏃‍♂️ Session Distance Compared to Others",style: Theme.of(context).textTheme.titleLarge),
            Divider(),
            SizedBox(height: 50,),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    for (int i = 0; i < allDistances.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: allDistances[i],
                          color: allDistances[i] == currentDistance ? const Color.fromARGB(255, 230, 65, 54) : const Color.fromARGB(255, 155, 154, 154),
                        ),
                      ])
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            Center(
              child: Text(
                currentDistance > maxDistance * 0.5
                    ? "🔥 Good job! Your pet was very active!"
                    : "🚶‍♂️ Try to walk your pet more next time.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
