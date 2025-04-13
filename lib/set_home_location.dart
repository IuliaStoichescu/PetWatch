import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_watch/map_logic/map.dart';

class SetHomeLocationPage extends StatefulWidget {
  final String petName;
  final String petImageUrl;
  final String petId;

  const SetHomeLocationPage({super.key,required this.petId, required this.petName, required this.petImageUrl});

  @override
  State<SetHomeLocationPage> createState() => _SetHomeLocationPageState();
}

class _SetHomeLocationPageState extends State<SetHomeLocationPage> {
  LatLng? selectedLocation;
  late GoogleMapController _mapController;
  final user = FirebaseAuth.instance.currentUser!;

  Future<void> saveHomeLocation(String userId, String petId, LatLng location) async {
  await FirebaseFirestore.instance
      .collection("users")
      .doc(userId)
      .collection("pets")
      .doc(petId)
      .collection("pet_info")
      .doc("home")
      .set({
        'lat': location.latitude,
        'lng': location.longitude,
      });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set Home Location")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(45.7489, 21.2087), // Default to somewhere like Timișoara
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng pos) {
              setState(() {
                selectedLocation = pos;
              });
            },
            markers: selectedLocation != null
                ? {
                    Marker(
                      markerId: MarkerId("home"),
                      position: selectedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    )
                  }
                : {},
          ),
    Positioned(
      bottom: 90,
      right: 16,
      child: FloatingActionButton(
        heroTag: 'zoom_in',
        backgroundColor: Colors.white,
        onPressed: () {
          _mapController.animateCamera(CameraUpdate.zoomIn());
        },
        child: Icon(Icons.add, color: Colors.black),
      ),
    ),

    Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        heroTag: 'zoom_out',
        backgroundColor: Colors.white,
        onPressed: () {
          _mapController.animateCamera(CameraUpdate.zoomOut());
        },
        child: Icon(Icons.remove, color: Colors.black),
      ),
    ),
          if (selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () async {
                    if (selectedLocation == null) return;

                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("pets")
                        .doc(widget.petId)
                        .collection("pet_info")
                        .doc("home")
                        .set({
                          'lat': selectedLocation!.latitude,
                          'lng': selectedLocation!.longitude,
                        });

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPage(
                          petName: widget.petName,
                          petImageUrl: widget.petImageUrl,
                          initialLocation: selectedLocation!,
                        ),
                      ),
                    );
                  },
                icon: Icon(Icons.check),
                label: Text("Confirm Home Location"),
              ),
            ),
        ],
      ),
    );
  }
}
