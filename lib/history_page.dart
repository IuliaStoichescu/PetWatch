import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/map_logic/pet_heatmap_page.dart';
import 'package:pet_watch/session_analytics_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final user = FirebaseAuth.instance.currentUser!;
  String? selectedPetId;
  String? selectedPetName;
  String? selectedPetImage;
  final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat timeFormatter = DateFormat('HH:mm');

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return Scaffold(
    drawer: _buildDrawer(),
    body: Stack(
      children: [
        ClipPath(
          clipper: BottomWaveClipper(),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 155, 109, 125),
                   Color.fromARGB(255, 155, 109, 125),
                   Color.fromARGB(255, 155, 109, 125),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  l10n.historyPageTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                )
              ],
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: 120), 
          child: selectedPetId == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.selectPetPrompt,style: TextStyle(fontSize: 15),),
                    LottieBuilder.asset("assets/select_pet.json")
                  ],
                )
                
                )
              : _buildSessionList(),
        ),
      ],
    ),
  );
}
Widget _buildDrawer() {
  final l10n = AppLocalizations.of(context)!;
  return Drawer(
    child: FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pets")
          .get(),
      builder: (context, petSnapshot) {
        if (petSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!petSnapshot.hasData || petSnapshot.data!.docs.isEmpty) {
          return Center(child: Text(l10n.noPetsFound));
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color.fromARGB(255, 155, 109, 125),),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.yourPets, style: TextStyle(color: Colors.white, fontSize: 24)),
                  SizedBox(width: 20,),
                  Icon(Icons.pets,color: const Color.fromARGB(255, 52, 41, 38),)
                ],
              ),
            ),
            ...petSnapshot.data!.docs.map((doc) {
              final petId = doc.id;
              final detailsRef = doc.reference.collection("pet_info").doc("details");

              return FutureBuilder<DocumentSnapshot>(
                future: detailsRef.get(),
                builder: (context, detailsSnapshot) {
                  if (!detailsSnapshot.hasData || !detailsSnapshot.data!.exists) return SizedBox();

                  final petData = detailsSnapshot.data!.data() as Map<String, dynamic>;
                  final name = petData["name"] ?? "Unnamed";
                  final imageUrl = petData["imageUrl"] ?? "";

                  return Column(
                    children: [
                      ListTile(
                        trailing: ElevatedButton.icon(
                          icon: Icon(Icons.insights,color: Colors.red,),
                          label: Text(l10n.heatmap, style: TextStyle(fontSize: 12,color: Colors.red)),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            textStyle: TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final home = await _getHome(petId);
                            if (home != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PetHeatmapPage(
                                    petId: petId,
                                    petName: name,
                                    homeLocation: home,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.noHomeFound)),
                              );
                            }
                          },
                        ),
                        leading: CircleAvatar(
                          backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl.isEmpty ? Icon(Icons.pets) : null,
                        ),
                        title: Text(name),
                        onTap: () {
                          Navigator.pop(context); 
                          setState(() {
                            selectedPetId = petId;
                            selectedPetName = name;
                            selectedPetImage = imageUrl;
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      SizedBox(height: 4), 
                    ],
                  );

                },
              );
            }),
          ],
        );
      },
    ),
  );
}


  Widget _buildSessionList() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pets")
          .doc(selectedPetId!)
          .collection("pet_info")
          .doc("data")
          .collection("sessions")
          .orderBy("start_time", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.noSessionHistory(selectedPetName ?? "this pet")),
                SizedBox(height: 10,),
                Lottie.asset("assets/no_pet_history_found.json",width: 70,height: 70)
              ],
            ));
        }


        return ListView(
          padding: EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final start = DateTime.parse(data["start_time"]);
            final end = DateTime.parse(data["end_time"]);
            final duration = Duration(seconds: data["duration_seconds"]);
            final distance = data["distance_meters"];

            return Card(
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionAnalyticsPage(
                        petId: selectedPetId!,
                        currentSession: data, // Pass the session's full document data
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundImage: selectedPetImage != null && selectedPetImage!.isNotEmpty
                      ? NetworkImage(selectedPetImage!)
                      : null,
                  child: selectedPetImage == null || selectedPetImage!.isEmpty
                      ? Icon(Icons.pets)
                      : null,
                ),
                title: Text(l10n.sessionDate(dateFormatter.format(start))),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.startTime(timeFormatter.format(start))),
                    Text(l10n.endTime(timeFormatter.format(end))),
                    Text(l10n.durationLabel(_formatDuration(duration))),
                    Text(l10n.distanceLabel((distance / 1000).toStringAsFixed(2))),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(duration.inHours);
    final m = twoDigits(duration.inMinutes.remainder(60));
    final s = twoDigits(duration.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  Future<LatLng?> _getHome(String petId) async {
  final doc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("pets")
      .doc(petId)
      .collection("pet_info")
      .doc("home")
      .get();

  if (doc.exists && doc.data() != null) {
    final data = doc.data()!;
    return LatLng(data['lat'], data['lng']);
  }
  return null;
}


}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);

    var firstControlPoint = Offset(size.width / 2, size.height);
    var firstEndPoint = Offset(size.width, size.height - 40);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


