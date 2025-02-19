import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pet_watch/login_signin/myTextField.dart';
import 'package:pet_watch/login_signin/my_button.dart';
import 'package:pet_watch/login_signin/services/auth_service.dart';
import 'package:pet_watch/login_signin/square_tile.dart';

class SigninPage extends StatefulWidget {
  final Function()? onTap;

  const SigninPage({super.key,required this.onTap});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  //final usernameController = TextEditingController();

  final passwordController = TextEditingController();

  final emailController = TextEditingController();

  final confirmController = TextEditingController();

  void signIn() async
  {
    showDialog(context: context, builder: (context){
      return const Center(
        child: CircularProgressIndicator(
        ),
      );
    });
    //log in
    try{
      if(passwordController.text == confirmController.text){
          await FirebaseAuth.instance.createUserWithEmailAndPassword
              (email: emailController.text, 
              password: passwordController.text, 
              );    
      }else{
        messagePopOut("The passwords you put in don't match. try again.");
      }        
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
              Color(0xFFFFC3A0), // Light Peach
              Color(0xFFE08DFF), // Light Pink-Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
               // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 10,),
                  Row(
                    children: [
                      SizedBox(width: 20,),
                      Column(
                        children: [
                          Text("Create",style: TextStyle(
                            fontFamily: "InstrumentSans",
                            fontSize: 50,
                           // decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            color: Colors.white
                          ),),
                            Text("  account",style: TextStyle(
                            fontFamily: "InstrumentSans",
                            fontSize: 50,
                           // decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            color: Colors.white
                          ),),
                        ],
                      ),
                      SizedBox(width: 50,),
                      FaIcon(
                          FontAwesomeIcons.paw, 
                          size: 70, 
                          color: Colors.white, 
                        ),
                    ],
                  ),
              
                  SizedBox(height: 10,),
                  //Mytextfield(controller: usernameController, hintText: "Username", prefixIcon: Icon(FontAwesomeIcons.user, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: false),
                  SizedBox(height: 30,),
                  Mytextfield(controller: emailController, hintText: "Email", prefixIcon: Icon(Icons.email_outlined, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: false),
                  SizedBox(height: 30,),
                  Mytextfield(controller: passwordController, hintText: "Password", prefixIcon: Icon(Icons.key_outlined, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: true),
                  SizedBox(height: 30,),
                  Mytextfield(controller: confirmController, hintText: "Confirm Password", prefixIcon: Icon(Icons.verified, color: const Color.fromARGB(255, 255, 255, 255)), obscureText: true),
                  SizedBox(height: 50,),
                  MyButton(onTap: signIn,text: "Sign Up",),  
                  SizedBox(height: 40,),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: const Color.fromARGB(255, 44, 44, 44),
                        ),
                      ),
                      Text("Or register with",style: TextStyle(color: const Color.fromARGB(255, 44, 44, 44)),) ,
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: const Color.fromARGB(255, 44, 44, 44),
                        ),
                      ),
                    ],
                  )  ,
                  SizedBox(height: 20,),
                   Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SquareTile(imagePath: "assets/login_signup/googleLogo.png", imageSize: 40,imageHeight: 40,onTap: ()=> AuthService().signInWithGoogle(),),//=> AuthService().signInWithGoogle()
                            SizedBox(width: 30), 
                            SquareTile(imagePath: "assets/login_signup/appleLogo.png", imageSize: 40,imageHeight: 40,onTap: (){},),
                          ],),
                  SizedBox(height: 50,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?",style: TextStyle(color: Colors.white)),
                      GestureDetector
                        (
                         onTap: widget.onTap,/*() {
                              Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
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
                          Center(
                            child: Text(
                              " Log In",
                              style: TextStyle(
                                color: const Color.fromARGB(255, 44, 44, 44),
                                decoration: TextDecoration.underline
                            ),),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}