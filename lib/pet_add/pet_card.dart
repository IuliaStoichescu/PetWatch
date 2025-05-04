import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:pet_watch/map_logic/map.dart';
import 'package:pet_watch/map_logic/services/storage_service.dart';
import 'package:pet_watch/pet_add/add_pet.dart';
import 'package:pet_watch/set_home_location.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PetList extends StatefulWidget {
  const PetList({super.key});

  @override
  _PetListState createState() => _PetListState();
}

class _PetListState extends State<PetList> {
  final User user = FirebaseAuth.instance.currentUser!;
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pets")
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> petSnapshot) {
        if (petSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!petSnapshot.hasData || petSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.noPetsMessage,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                lottie.Lottie.asset("assets/missing_animation.json"),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(16),
          children: petSnapshot.data!.docs.map((petDoc) {
            return FutureBuilder(
              future: petDoc.reference.collection("pet_info").doc("details").get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> detailsSnapshot) {
                if (detailsSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!detailsSnapshot.hasData || !detailsSnapshot.data!.exists) {
                  return SizedBox(); 
                }

                var petDetails = detailsSnapshot.data!.data() as Map<String, dynamic>;

                return PetCard(petId: petDoc.id,petDetails: petDetails);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class PetCard extends StatefulWidget {
  final String petId; // ID of the pet
  final Map<String, dynamic> petDetails;

  const PetCard({required this.petId, required this.petDetails, super.key});

  @override
  _PetCardState createState() => _PetCardState();
}

class _PetCardState extends State<PetCard> {
  bool isTrackingOn = false;
  final User user = FirebaseAuth.instance.currentUser!;
  final StorageService storageService = StorageService();
   Future<LatLng?> getHomeLocation(String userId, String petId) async {
  final doc = await FirebaseFirestore.instance
      .collection("users")
      .doc(userId)
      .collection("pets")
      .doc(petId)
      .collection("pet_info")
      .doc("home")
      .get();

  if (doc.exists) {
    final data = doc.data();
    if (data != null && data.containsKey('lat') && data.containsKey('lng')) {
      return LatLng(data['lat'], data['lng']);
    }
  }
  return null;
}
Future<void> _cleanupSession() async {
  await storageService.clearSessionState(widget.petId);
  await storageService.savePolyline(widget.petId, []);
  await storageService.saveLastKnownMarker(widget.petId, LatLng(0, 0));
  await storageService.clearEventMarkers(widget.petId);
  await storageService.saveGeofenceExitCount(widget.petId, 0);
}

  @override
  Widget build(BuildContext context) {
    String petName = widget.petDetails["name"] ?? "Unnamed Pet";
    String sex = widget.petDetails["sex"] ?? "Unknown";
    String weight = widget.petDetails["kilograms"] ?? "N/A";
    String about = widget.petDetails["about"] ?? "No description available";
    String imageUrl = widget.petDetails["imageUrl"] ?? "";
    String breed = widget.petDetails["breed"] ?? "Unknown";
    String animalType = widget.petDetails["animalType"] ?? "Unknown";
    String birthDateString = widget.petDetails["birthDate"] ?? "Not provided";

   final l10n = AppLocalizations.of(context)!;

  String ageDisplay = l10n.unknownAge;

  if (birthDateString != "Not provided") {
    try {
      DateTime birthDate = DateTime.parse(birthDateString);
      Duration ageDuration = DateTime.now().difference(birthDate);
      int years = ageDuration.inDays ~/ 365;
      int months = (ageDuration.inDays % 365) ~/ 30;

      if (years > 0) {
        ageDisplay = l10n.yearsCount(years);
        if (months > 0) {
          ageDisplay += " ${l10n.monthsCount(months)}";
        }
      } else if (months > 0) {
        ageDisplay = l10n.monthsCount(months);
      } else {
        ageDisplay = l10n.lessThanMonth;
      }
    } catch (e) {
      ageDisplay = l10n.invalidDate;
    }
  }



    bool isFemale = sex.toLowerCase() == "female";
    IconData genderIcon = isFemale ? Icons.female : Icons.male;
    Color genderColor = isFemale ? Colors.pinkAccent : Colors.blueAccent;

    final StorageService storageService = StorageService();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: GFCard(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Stack(
          children: [
            Row(
              children: [
                // Pet Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : Icon(Icons.pets, size: 50, color: Color(0xFF6C4C57)),
                ),
                SizedBox(width: 10),
      
                // Pet Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text("${l10n.nameLabel}: $petName", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("${l10n.animalLabel}: $animalType", style: TextStyle(fontSize: 16)),
                        Text("${l10n.breedLabel}: $breed", style: TextStyle(fontSize: 16)),
                        Text("${l10n.ageLabel}: $ageDisplay", style: TextStyle(fontSize: 16)),
                        Row(
                          children: [
                            Text("${l10n.sexLabel}: $sex", style: TextStyle(fontSize: 16)),
                            SizedBox(width: 5),
                            Icon(genderIcon, color: genderColor, size: 24),
                          ],
                        ),
                        Text("${l10n.weightLabel}: $weight", style: TextStyle(fontSize: 16)),
                        Divider(thickness: 1, color: Colors.black),
                        Text("${l10n.aboutLabel}: $about", style: TextStyle(fontSize: 14), overflow: TextOverflow.visible),
                      ],
                  ),
                ),
                SizedBox(width: 30,),
      
                // Toggle & Arrow Button
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(height: 30,),
                    Transform.scale(
                      scale: 1.2,
                      child: Switch(
                        value: isTrackingOn,
                       onChanged: (value) async {
                          setState(() {
                            isTrackingOn = value;
                          });

                          if (!value) { // When turning tracking off
                            try {
                              final sessionData = await storageService.loadSessionState(widget.petId);
                              final int geofenceExitCount = await storageService.loadGeofenceExitCount(widget.petId);
                              print("Debug - loaded sessionData: $sessionData");
                              
                              // Check if we have a valid session with start time
                              final outStartTime = sessionData['outStartTime'];
                              if (outStartTime == null) {
                                print("❌ Cannot save session: outStartTime is null");
                                await _cleanupSession();
                                return;
                              }
                              
                              // Load event markers with try-catch to isolate any errors
                              Map<String, Marker> eventMarkers = {};
                              try {
                                eventMarkers = await storageService.loadEventMarkers(widget.petId, context);
                              } catch (e) {
                                print("⚠️ Error loading event markers: $e");
                                // Continue with empty event markers rather than failing
                              }
                              
                              final endTime = DateTime.now();
                              final duration = endTime.difference(outStartTime);
                              final List<LatLng> petPath = sessionData['polyline'] ?? [];
                              
                              // Safe conversion to required data structures
                              final pathData = petPath.map((p) => {
                                "lat": p.latitude, 
                                "lon": p.longitude
                              }).toList();
                              
                              final eventList = eventMarkers.entries.map((entry) {
                                final marker = entry.value;
                                final String id = entry.key;
                                String type = "UNKNOWN";
                                String timeStr = DateTime.now().toIso8601String();
                                
                                if (id.contains("_")) {
                                  final parts = id.split("_");
                                  type = parts.first;
                                  if (parts.length > 1) {
                                    try {
                                      final timestamp = int.parse(parts.last);
                                      timeStr = DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String();
                                    } catch (e) {
                                      print("⚠️ Could not parse timestamp: $e");
                                    }
                                  }
                                }
                                
                                return {
                                  "type": type,
                                  "time": timeStr,
                                  "lat": marker.position.latitude,
                                  "lon": marker.position.longitude,
                                };
                              }).toList();
                              
                              final sessionObject = {
                                "start_time": outStartTime.toIso8601String(),
                                "end_time": endTime.toIso8601String(),
                                "duration_seconds": duration.inSeconds,
                                "distance_meters": sessionData['distance'] ?? 0.0,
                                "path": pathData,
                                "events": eventList,
                                "geofence_exits": geofenceExitCount
                              };
                              
                              // Add weather data if available
                              final weather = sessionData['weather'];
                              if (weather != null) {
                                sessionObject["weather"] = weather;
                              }
                              
                              await FirebaseFirestore.instance
                                .collection("users")
                                .doc(user.uid)
                                .collection("pets")
                                .doc(widget.petId)
                                .collection("pet_info")
                                .doc("data")
                                .collection("sessions")
                                .add(sessionObject);
                                
                              print("✅ Session saved to Firebase from PetCard");
                            } catch (e, stackTrace) {
                              print("❌ Error saving session in PetCard: $e");
                              print("Stack trace: $stackTrace");
                            } finally {
                              // Cleanup regardless of success or failure
                              await _cleanupSession();
                            }
                          }
                        },

                        activeColor: Colors.green,
                        activeTrackColor: Colors.greenAccent,
                        inactiveThumbColor: const Color.fromARGB(255, 110, 0, 0),
                        inactiveTrackColor: Colors.red,
                      ),
                    ),
                    if (isTrackingOn)
                      GestureDetector(
                        onTap: () async {
                            final home = await getHomeLocation(user.uid, widget.petId);

                            if (home == null) {
                              // Go to Set Home first
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SetHomeLocationPage(
                                    petId: widget.petId,
                                    petName: widget.petDetails["name"] ?? "Unnamed Pet",
                                    petImageUrl: widget.petDetails["imageUrl"] ?? "",
                                  ),
                                ),
                              );
                            } else {
                              // Home is set, go directly to MapPage
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPage(
                                    petId: widget.petId,
                                    petName: widget.petDetails["name"] ?? "Unnamed Pet",
                                    petImageUrl: widget.petDetails["imageUrl"] ?? "",
                                    initialLocation: home,
                                  ),
                                ),
                              );
                            }
                          },

                        child: Icon(Icons.arrow_forward, color: Colors.black, size: 30),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: -5,
              right: 30,
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.green),
                onPressed: () {
              showAddPetPopup(
                context,
                petId: widget.petId,
                existingData: widget.petDetails,
              );
            },
              ),
            ),
            Positioned(
              top: -5,
              right: 2,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeletePet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showAddPetPopup(BuildContext context, {String? petId, Map<String, dynamic>? existingData}) async {
  bool? petSaved = await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AddPet(
          petId: petId,
          existingPetData: existingData,
        ),
      );
    },
  );

  if (petSaved == true) {
    showSnackbar(context, "Pet profile saved successfully!", Colors.green);
  }
}
void showSnackbar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: Colors.white)),
      backgroundColor: color,
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating, 
      margin: EdgeInsets.all(20), 
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), 
      ),
    ),
  );
}

Future<void> _deletePet() async {
   final l10n = AppLocalizations.of(context)!;
  try {
    final petRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pets")
        .doc(widget.petId);

    final petInfoRef = petRef.collection("pet_info");

    final subcollections = ["details", "home", "data"];
    for (String subDoc in subcollections) {
      final docRef = petInfoRef.doc(subDoc);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
      }
    }
    final sessionsRef = petInfoRef.doc("data").collection("sessions");
    final sessions = await sessionsRef.get();
    for (final doc in sessions.docs) {
      await doc.reference.delete();
    }
    await petRef.delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.petDeletedMessage),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e, stack) {
    print("❌ Error deleting pet and data: $e");
    print(stack);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.petDeleteFailed),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  void _confirmDeletePet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.deletePetTitle),
          content: Text(l10n.deletePetConfirm),
          actions: [
            TextButton(
              child: Text(l10n.cancelButton),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(l10n.deleteButton, style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(context);
                _deletePet();
              },
            ),
          ],
        );
      },
    );
  }
}