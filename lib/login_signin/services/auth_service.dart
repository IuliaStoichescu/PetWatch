import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  signInWithGoogle() async{

    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn(); // begin interactive sign in

    if(gUser==null) return;

    final GoogleSignInAuthentication gAuth = await gUser.authentication; // auth details fromn request

    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken
    ); // new credential for user

    return await FirebaseAuth.instance.signInWithCredential(credential); // sign in
  }
}