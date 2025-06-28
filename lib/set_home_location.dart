import 'dart:convert';
import 'dart:ui' as ui;

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_watch/map_logic/map.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SetHomeLocationPage extends StatefulWidget {
  final String petName;
  final String petImageUrl;
  final String petId;

  const SetHomeLocationPage({super.key, required this.petId, required this.petName, required this.petImageUrl});

  @override
  State<SetHomeLocationPage> createState() => _SetHomeLocationPageState();
}

class _SetHomeLocationPageState extends State<SetHomeLocationPage> {
  LatLng? selectedLocation;
  late GoogleMapController _mapController;
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  String get apiKey => dotenv.env['API_PLACES'] ?? '';

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

  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['predictions'];
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['result']['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        
        setState(() {
          selectedLocation = LatLng(lat, lng);
          _searchResults = [];
          _searchController.clear();
        });
        
        _mapController.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(lat, lng),
          15,
        ));
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context)!;
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
            title: l10n.setHomeTitle,
            message: l10n.setHomeMessage,
            contentType: ContentType.help,
            color: ui.Color.fromARGB(255, 60, 214, 193),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
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
          child: AppBar(
            iconTheme: IconThemeData(color: Colors.white),
            title: Text(l10n.setHomeTitle, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            initialCameraPosition: CameraPosition(
              target: LatLng(45.7489, 21.2087), // Default location
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng pos) {
              setState(() {
                selectedLocation = pos;
                _searchResults = [];
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
          
          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchLocation ,
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  if (value.length > 2) {
                    searchPlaces(value);
                  } else if (value.isEmpty) {
                    setState(() {
                      _searchResults = [];
                    });
                  }
                },
              ),
            ),
          ),
          
          // Search results
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(result['description']),
                      onTap: () {
                        getPlaceDetails(result['place_id']);
                      },
                    );
                  },
                ),
              ),
            ),
            
          // Loading indicator
          if (_isSearching)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: ui.Color.fromARGB(255, 60, 214, 193),
                  ),
                ),
              ),
            ),

          // Zoom controls
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
          
          // Confirm button
          if (selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 60, 214, 193),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                icon: Icon(Icons.check, color: Colors.white),
                label: Text(l10n.confirmHomeButton),
              ),
            ),
        ],
      ),
    );
  }
}
