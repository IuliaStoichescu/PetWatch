import 'dart:ui' as ui;

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
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
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        content: AwesomeSnackbarContent(
          title: 'Set Home Location',
          message: '📍 Tap on map to set home base for your pet',
          contentType: ContentType.help,
          color: ui.Color.fromARGB(255, 60, 214, 193),
        ),
      ),
    );
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container
        (
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ui.Color.fromARGB(255, 60, 214, 193), ui.Color.fromARGB(255, 60, 214, 193), ui.Color.fromARGB(255, 60, 214, 193)],
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
      child: AppBar(iconTheme: IconThemeData(color: Colors.white),title: Text("Set Home Location",style: TextStyle(color: Colors.white)),backgroundColor: Colors.transparent,))),
      body: Stack(
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
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
      top: 80,
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
      top: 150,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 60, 214, 193), // background color
                    foregroundColor: Colors.white, // text & icon color
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5), // less wide
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                          petId: widget.petId,
                          petName: widget.petName,
                          petImageUrl: widget.petImageUrl,
                          initialLocation: selectedLocation!,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.check,color: Colors.white,),
                  label: Text("Confirm Home Location"),
                )

            ),
        ],
      ),
    );
  }
}
