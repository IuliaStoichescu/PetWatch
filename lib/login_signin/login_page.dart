import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pet_watch/login_signin/myTextField.dart';
import 'package:pet_watch/login_signin/my_button.dart';
import 'package:pet_watch/login_signin/services/auth_service.dart';
import 'package:pet_watch/login_signin/square_tile.dart';

class LoginPage extends StatefulWidget {

  final Function()? onTap;
  const LoginPage({super.key,required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();

  final passwordController = TextEditingController();

  void logIn() async
  {
    //show loading circle while loging in 
    showDialog(context: context, builder: (context){
      return const Center(
        child: CircularProgressIndicator(),
      );
    });
    //log in
    try{
        await FirebaseAuth.instance.signInWithEmailAndPassword
      (email: usernameController.text, 
      password: passwordController.text, 
      );          
      //pop loading circle
      if(mounted){Navigator.pop(context);}
    }on FirebaseAuthException catch (e){
      if(mounted){
        Navigator.pop(context);
        }
      messagePopOut(e.code);
    }
  }

  void messagePopOut(String textDialog){
    showDialog(context: context, builder: (context){
      return  AlertDialog(
        title: Text(textDialog,style: TextStyle(color: Colors.white),),
        backgroundColor: const Color.fromARGB(99, 0, 0, 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, // Start from top left
            end: Alignment.bottomRight, // End at bottom right
            colors: [
              Color(0xFF73BDF3), // Light Blue
              Color(0xFF8A72F9), // Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40,),
                  Row(
                    children: [
                      SizedBox(width: 50,),
                      Column(
                        children: [
                          Text("Welcome",style: TextStyle(
                            fontFamily: "InstrumentSans",
                            fontSize: 50,
                           // decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            color: Colors.white
                          ),),
                            Text("back!     ",style: TextStyle(
                            fontFamily: "InstrumentSans",
                            fontSize: 50,
                           // decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            color: Colors.white
                          ),),
                        ],
                      ),
                      SizedBox(width: 40,),
                      FaIcon(
                          FontAwesomeIcons.paw, 
                          size: 70, 
                          color: Colors.white, 
                        ),
                    ],
                  ),
              
                  SizedBox(height: 50,),
                  Mytextfield(controller: usernameController, hintText: "Email", prefixIcon: Icon(Icons.email_outlined, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: false),
                  SizedBox(height: 30,),
                  Mytextfield(controller: passwordController, hintText: "Password", prefixIcon: Icon(Icons.key_outlined, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: true),
                  SizedBox(height: 30,),
                  Text("Forgot your password?",style: TextStyle(color: Colors.white),) ,
                  SizedBox(height: 10,), 
                  MyButton(onTap: logIn,text :"Log In"),   
                  SizedBox(height: 19,),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: const Color.fromARGB(255, 44, 44, 44),
                        ),
                      ),
                      Text("Or continue with",style: TextStyle(color: const Color.fromARGB(255, 44, 44, 44)),) ,
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: const Color.fromARGB(255, 44, 44, 44),
                        ),
                      ),
                    ],
                  )  ,
                  SizedBox(height: 10),
                  SizedBox(
                    height: 280,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -30, 
                          bottom: 30, 
                          child: Image.asset(
                            "assets/login_signup/petOwner.png",
                            width: 250, 
                            height: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                    
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SquareTile(imagePath: "assets/login_signup/googleLogo.png", imageSize: 40,imageHeight: 40,onTap: ()=>AuthService().signInWithGoogle()),//=>AuthService().signInWithGoogle(),
                             // SizedBox(width: 30), 
                             // SquareTile(imagePath: "assets/login_signup/appleLogo.png", imageSize: 40,imageHeight: 40,onTap: (){},),
                            ],),
                      ],
                    ),
                  ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Not registered Yet?",style: TextStyle(color: Colors.white),),
                        GestureDetector
                        (
                          onTap: widget.onTap,/*() {
                              Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => SigninPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                  ),
                                );

                            },*/
                          child: 
                          Text(
                            " Register now!",
                            style: TextStyle(
                              color: const Color.fromARGB(255, 44, 44, 44),
                              decoration: TextDecoration.underline
                          ),))
                      ],
                    ),
                ],
              ),
            ),
          ),
        )
      ),
    );
  }
}