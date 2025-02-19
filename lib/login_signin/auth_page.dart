import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pet_watch/home_page.dart';
import 'package:pet_watch/login_signin/login_or_signup.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});
  //page that verifies if there is already an account
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          //user is logged in
          if(snapshot.hasData){
            return HomePage();
          }
          //user is not logged in
          else { return LoginOrSignup();}
        },
      ),
    );
  }
}