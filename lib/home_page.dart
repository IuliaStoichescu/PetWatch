import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_watch/helpers/square_fab.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  final user = FirebaseAuth.instance.currentUser!;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color.fromARGB(255, 108, 76, 87), const Color.fromARGB(255, 108, 76, 87), const Color.fromARGB(255, 108, 76, 87)], // Gradient galben → portocaliu → roșu
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30), // Rotunjire doar jos
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3), // Umbra dedesubt
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent, // Pentru a păstra gradientul
            elevation: 0, // Fără umbră suplimentară
            title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.person,size: 25,color: Colors.white,),
            SizedBox(width: 15,),
            Text("Glad to have you , ${getUserFirstName(user)}",style: TextStyle(color: Colors.white),),
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
        ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text("Home Screen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 400), 
            Text("More content goes here..."),
          ],
        ),

        Positioned(
          bottom: 40, 
          left: MediaQuery.of(context).size.width / 2 - 30, 
          child: SquareFab(
            onPressed: () {
              print("Add pet profile!");
            },
          ),
        ),
      ],
    ),
    );
  }
}

String getFirstNameFromEmail(String email) {
  if (email.contains('@')) {
    String username = email.split('@')[0]; // Extrage partea înainte de @
    return username.split('.')[0].capitalize(); // Extrage prenumele
  }
  return email; // Fallback dacă emailul este invalid
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
