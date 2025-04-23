import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as mathing;
import 'dart:ui' as ui;
import 'package:pet_watch/map_logic/widgets/pulsing_circle_widget.dart';

class PetHeatmapPage extends StatefulWidget {
  final String petId;
  final String petName;
  final LatLng homeLocation;

  const PetHeatmapPage({
    required this.petId,
    required this.petName,
    required this.homeLocation,
    super.key,
  });

  @override
  State<PetHeatmapPage> createState() => _PetHeatmapPageState();
}

class _PetHeatmapPageState extends State<PetHeatmapPage> {
  GoogleMapController? _mapController;
  List<LatLng> circleCenters = [];
  final user = FirebaseAuth.instance.currentUser!;
  Set<Circle> heatCircles = {};
  CameraPosition? _lastCameraPosition;
  bool isDarkMap = false;
  String? _currentMapStyle;

  @override
  void initState() {
    super.initState();
    _generateHeatmap();
  }

  Future<void> _setMapStyle() async {
  final stylePath = isDarkMap
      ? 'assets/map_themes/dark_mode.json'
      : 'assets/map_themes/light_mode.json';

  final style = await DefaultAssetBundle.of(context).loadString(stylePath);
  if (mounted) {
    setState(() {
      _currentMapStyle = style;
    });
  }
}

  Future<void> _generateHeatmap() async {
    Map<String, int> frequency = {};

    final sessions = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pets")
        .doc(widget.petId)
        .collection("pet_info")
        .doc("data")
        .collection("sessions")
        .get();

    for (var session in sessions.docs) {
  final data = session.data();

  if (!data.containsKey('path') || data['path'] is! List) {
    print("⚠️ Skipping session ${session.id}: No valid 'path' field found.");
    continue;
  }
  else print("✅ Valid path found in session ${session.id}: ${data['path']}");


  final path = data['path'] as List<dynamic>;

  for (var point in path) {
    if (point is Map && point.containsKey('lat') && point.containsKey('lon')) {
      double lat = point['lat'];
      double lon = point['lon'];

      final dist = Geolocator.distanceBetween(
        widget.homeLocation.latitude,
        widget.homeLocation.longitude,
        lat,
        lon,
      );
      if (dist <= 20) continue; // Skip home zone

      String key = '${(lat * 10000).round()},${(lon * 10000).round()}';
      frequency[key] = (frequency[key] ?? 0) + 1;
    }
  }
}


    List<LatLng> centers = [];

frequency.forEach((key, count) {
  final parts = key.split(',');
  double lat = int.parse(parts[0]) / 10000;
  double lon = int.parse(parts[1]) / 10000;

  final center = LatLng(lat, lon);
  centers.add(center);
});

setState(() {
  circleCenters = centers;
});
  }

void helpMiniWindow(BuildContext context) {
  if (!mounted) return;

  OverlayState overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: AppBar().preferredSize.height + 10,
      right: 10,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMap
                ? const ui.Color.fromARGB(255, 11, 84, 111)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.deepOrange, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Heatmap Info",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDarkMap ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(),
              Text(
                "🔥 The heatmap shows where your pet has spent the most time during walks or activity.",
                style: TextStyle(
                    fontSize: 14,
                    color: isDarkMap ? Colors.white : Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                "Red pulsing circle areas = more frequent visits.\n🏠 The area near home is ignored by default.\n📍 Multiple sessions are analyzed.\n Explore the map to see where your pet likes to hang out!",
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDarkMap ? Colors.white70 : Colors.black87),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    overlayEntry.remove();
                  },
                  child: Text("Close",
                      style: TextStyle(
                          color: isDarkMap
                              ? Colors.white
                              : const ui.Color.fromARGB(255, 47, 36, 66))),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlayState.insert(overlayEntry);
}


 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title:
     Text("${widget.petName}'s Heatmap 🔥",style: TextStyle(color: Colors.white),),
     backgroundColor: const Color.fromARGB(255, 193, 52, 42),
     centerTitle: true,
     iconTheme: IconThemeData(color: Colors.white),
     actions: [
       IconButton(
                icon: Icon(
                  isDarkMap ? Icons.dark_mode : Icons.light_mode,
                  color:isDarkMap? Colors.white: const ui.Color.fromARGB(255, 255, 243, 79),
                ),
                onPressed: () async {
                  setState(() {
                    isDarkMap = !isDarkMap;
                  });
                  await _setMapStyle();
                },
              ),
      IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => helpMiniWindow(context),
              ),
     ],
     ),
    body: Stack(
      children: [
        GoogleMap(
           style: _currentMapStyle,
          myLocationButtonEnabled: false,
          onCameraMove: (position) {
            _lastCameraPosition = position;
            setState(() {}); // triggers rebuild of PulsingCircle widgets
          },
          initialCameraPosition: CameraPosition(
            target: widget.homeLocation,
            zoom: 15,
          ),
          onMapCreated: (controller) => setState(() {
            _mapController = controller;
          }),
          myLocationEnabled: false,
        ),
        if (_mapController != null)
          ...circleCenters.map((position) => PulsingCircle(
                position: position,
                radius: 100,
                opacity: 0.4,
                mapController: _mapController!,
              )),
      ],
    ),
  );
}
}
