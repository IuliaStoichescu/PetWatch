import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // for pie and bar charts

class SessionAnalyticsPage extends StatefulWidget {
  final String petId;
  final Map<String, dynamic> currentSession;

  const SessionAnalyticsPage({
    required this.petId,
    required this.currentSession,
    super.key,
  });

  @override
  State<SessionAnalyticsPage> createState() => _SessionAnalyticsPageState();
}

class _SessionAnalyticsPageState extends State<SessionAnalyticsPage> {
  final user = FirebaseAuth.instance.currentUser!;

  final List<String> positiveMessages = [
  "🔥 Good job! Your pet was very active!",
  "🎉 That was an amazing walk!",
  "🏅 Your pet hit a new milestone!",
  "🐾 Active pets are happy pets!",
  "🚀 Keep it up! Great exercise!",
  "🌟 Excellent session! Your pet loved it!",
];

final List<String> encouragementMessages = [
  "🚶‍♂️ Try to walk your pet more next time.",
  "🦴 Your pet could use more activity.",
  "🏃‍♀️ Let's explore more next time!",
  "🕒 Short session! Go a bit longer next time.",
  "📉 That walk was too brief!",
  "🐶 Your pet needs more outdoor fun!",
];


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

  final homeDoc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("pets")
      .doc(widget.petId)
      .collection("pet_info")
      .doc("home")
      .get();

  final homeLat = homeDoc.data()?['lat'];
  final homeLng = homeDoc.data()?['lng'];

  if (homeLat == null || homeLng == null) {
    print("⚠️ Home location is missing");
    return;
  }

  double longest = 0;
  double longestDistance = 0;
  List<double> distances = [];

  int nearHome = 0;
  int away = 0;

  for (var doc in sessions.docs) {
    final data = doc.data();
    final dur = data['duration_seconds']?.toDouble() ?? 0;
    final dist = data['distance_meters']?.toDouble() ?? 0;
    final path = data['path'] as List<dynamic>?;

    distances.add(dist);
    if (dur > longest) longest = dur;
    if (dist > longestDistance) longestDistance = dist;

    if (path != null) {
      for (var point in path) {
        if (point['lat'] != null && point['lon'] != null) {
          final double lat = point['lat'];
          final double lon = point['lon'];

          final double distance = Geolocator.distanceBetween(
            homeLat,
            homeLng,
            lat,
            lon,
          );

          if (distance <= 300) {
            nearHome++;
          } else {
            away++;
          }
        }
      }
    }
  }

  final total = nearHome + away;

  setState(() {
    currentDuration = widget.currentSession['duration_seconds'].toDouble();
    currentDistance = widget.currentSession['distance_meters'].toDouble();
    maxDuration = longest;
    maxDistance = longestDistance;
    allDistances = distances;
    homeTimePercentage = total > 0 ? nearHome / total * 100 : 0;
    outsideTimePercentage = total > 0 ? away / total * 100 : 0;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Color.fromARGB(255, 1, 62, 123),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text("Session Analysis",style: TextStyle(color: Colors.white),),backgroundColor: Color.fromARGB(255, 1, 62, 123),),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("📊 Session Stats", style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, // or any custom color
                ),),
              Divider(),
              SizedBox(height: 10),
              Text(
                currentDuration!=maxDuration?
              "⏱️ Duration: ${(100 - (currentDuration / maxDuration * 100)).toStringAsFixed(1)}% less than the longest session":
              "⏱️ This is your pets longest session!",
              style: TextStyle(fontSize: 16,color: Colors.white),
            ),
            Text(
              currentDistance!=maxDistance?
              "📏 Distance: ${(100 - (currentDistance / maxDistance * 100)).toStringAsFixed(1)}% less than the longest distance":
              "📏 This is your pets longest distance!",
              style: TextStyle(fontSize: 16,color: Colors.white),
            ),
          
              SizedBox(height: 20),
          
              Text("📍 Near Home vs Away",style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, // or any custom color
                ),),
              Divider(),
              SfCircularChart(
                legend: Legend(isVisible: true,textStyle: TextStyle(color: Colors.white)),
                series: <CircularSeries>[
                  PieSeries<_PieData, String>(
                    dataSource: [
                      _PieData('Near Home', homeTimePercentage, const Color.fromARGB(255, 249, 157, 91)),
                      _PieData('Away', outsideTimePercentage, const Color.fromARGB(255, 227, 89, 121)),
                    ],
                    xValueMapper: (_PieData data, _) => data.label,
                    yValueMapper: (_PieData data, _) => data.value,
                    pointColorMapper: (_PieData data, _) => data.color,
                    dataLabelMapper: (_PieData data, _) =>
                    data.value == 0 ? '' : '${data.label} ${data.value.toStringAsFixed(1)}%',
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.inside,
                      textStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white, 
                      ),
                    ),
          
                  ),
                ],
              ),
          
              SizedBox(height: 20),
          
              Text("🏃‍♂️ Session Distance Compared to Others",style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, // or any custom color
                ),),
              Divider(),
              SizedBox(height: 50,),
             
             SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                  axisLine: AxisLine(color: Colors.white),
                  title: AxisTitle(
                    text: 'Session Number', // Label for X-axis
                    textStyle: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  labelStyle: TextStyle(color: Colors.white), // <-- white x-axis labels
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(
                    text: 'Distance (meters)', // Label for Y-axis
                    textStyle: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  axisLine: AxisLine(color: Colors.white),
                  labelStyle: TextStyle(color: Colors.white), // <-- white y-axis labels
                ),
                  series: <CartesianSeries<BarData, String>>[
                    ColumnSeries<BarData, String>(
                      dataSource: List.generate(allDistances.length, (index) => BarData(
                        label: '$index',
                        value: allDistances[index],
                        color: allDistances[index] == currentDistance
                            ? const Color.fromARGB(255, 40, 228, 190)
                            : const Color.fromARGB(255, 249, 157, 91),
                      )),
                      xValueMapper: (BarData data, _) => data.label,
                      yValueMapper: (BarData data, _) => data.value,
                      pointColorMapper: (BarData data, _) => data.color,
                      dataLabelSettings: DataLabelSettings(isVisible: false),
                    )
                  ],
                ),
              SizedBox(height: 20),
          
              Center(
                child: Text(
                  currentDistance > maxDistance * 0.5
                      ? (positiveMessages..shuffle()).first
                      : (encouragementMessages..shuffle()).first,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _PieData {
  final String label;
  final double value;
  final Color color;
  _PieData(this.label, this.value, this.color);
}

class BarData {
  final String label;
  final double value;
  final Color color;
  BarData({required this.label, required this.value, required this.color});
}
