import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pet_watch/helpers/square_fab.dart';
import 'package:pet_watch/pet_add/add_pet.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User user = FirebaseAuth.instance.currentUser!;
  List<String> items = []; 

  void logUserout() {
    FirebaseAuth.instance.signOut();
  }

  String getUserFirstName(final user) {
    String firstName = "";
    if (user != null && user.email != null) {
      firstName = getFirstNameFromEmail(user.email!);
    }
    return firstName;
  }

  void addItem() {
    setState(() {
      items.add("Pet Profile ${items.length + 1}"); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C4C57), Color(0xFF6C4C57), Color(0xFF6C4C57)],
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.person, size: 25, color: Colors.white),
                SizedBox(width: 15),
                Text(
                  "Glad to have you, ${getUserFirstName(user)}",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: logUserout,
                icon: Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          items.isEmpty
              ? Center(
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
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(items[index]),
                      ),
                    );
                  },
                ),

          Positioned(
            bottom: 40,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: SquareFab(
              onPressed: () {
                 showAddPetPopup(context);
              },//addItem, 
            ),
          ),
        ],
      ),
    );
  }
}

String getFirstNameFromEmail(String email) {
  if (email.contains('@')) {
    String username = email.split('@')[0];
    return username.split('.')[0].capitalize();
  }
  return email;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

void showAddPetPopup(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: AddPet(),
      );
    },
  ).then((_) {
    showSnackbar(context, "Pet profile saved successfully!", Colors.green);
  });
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

