import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/map_logic/map.dart';

class PetList extends StatefulWidget {
  @override
  _PetListState createState() => _PetListState();
}

class _PetListState extends State<PetList> {
  final User user = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
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
                  "No pet profiles added yet!",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Lottie.asset("assets/missing_animation.json"),
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

  const PetCard({required this.petId, required this.petDetails, Key? key}) : super(key: key);

  @override
  _PetCardState createState() => _PetCardState();
}

class _PetCardState extends State<PetCard> {
  bool isTrackingOn = false;
  final User user = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    String petName = widget.petDetails["name"] ?? "Unnamed Pet";
    String sex = widget.petDetails["sex"] ?? "Unknown";
    String weight = widget.petDetails["kilograms"] ?? "N/A";
    String about = widget.petDetails["about"] ?? "No description available";
    String imageUrl = widget.petDetails["imageUrl"] ?? "";

    bool isFemale = sex.toLowerCase() == "female";
    IconData genderIcon = isFemale ? Icons.female : Icons.male;
    Color genderColor = isFemale ? Colors.pinkAccent : Colors.blueAccent;

    return GFCard(
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
                    ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                    : Icon(Icons.pets, size: 50, color: Color(0xFF6C4C57)),
              ),
              SizedBox(width: 10),

              // Pet Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Name: $petName", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Row(
                      children: [
                        Text("Sex: $sex", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 5),
                        Icon(genderIcon, color: genderColor, size: 24),
                      ],
                    ),
                    Text("Weight: $weight", style: TextStyle(fontSize: 16)),
                    Divider(thickness: 1, color: Colors.black,),
                    Text("About: $about", style: TextStyle(fontSize: 14, overflow: TextOverflow.ellipsis),overflow: TextOverflow.visible,),
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
                      onChanged: (value) {
                        setState(() {
                          isTrackingOn = value;
                        });
                      },
                      activeColor: Colors.green,
                      activeTrackColor: Colors.greenAccent,
                      inactiveThumbColor: const Color.fromARGB(255, 110, 0, 0),
                      inactiveTrackColor: Colors.red,
                    ),
                  ),
                  if (isTrackingOn)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MapPage()),
                          );// Navigate to map
                      },
                      child: Icon(Icons.arrow_forward, color: Colors.black, size: 30),
                    ),
                ],
              ),
            ],
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
    );
  }

  void _deletePet() async {
    try {
      // Delete the pet's details first
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pets")
          .doc(widget.petId)
          .collection("pet_info")
          .doc("details")
          .delete();

      // Delete the pet document itself
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pets")
          .doc(widget.petId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pet deleted successfully!"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("Error deleting pet: $e");
    }
  }

  void _confirmDeletePet(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Pet"),
          content: Text("Are you sure you want to delete this pet profile? This action cannot be undone."),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
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