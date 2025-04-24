import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_watch/login_signin/auth_page.dart';
import 'package:pet_watch/login_signin/services/storage_service.dart';
import 'package:pet_watch/map_logic/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_watch/home_page.dart';
import 'package:pet_watch/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ Ensure async code runs before UI
  NotificationService().initNotification();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyAiW08ANESI0E-Pj98AaQXMsb82jL37ceA",
        authDomain: "mypetwatchapplication.firebaseapp.com",
        projectId: "mypetwatchapplication",
        storageBucket: "mypetwatchapplication.firebasestorage.app",
        messagingSenderId: "118660317591",
        appId: "1:118660317591:web:510523d1fb7b05f9c144d2"
      ),
    );
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool("seenOnboarding") ?? false; // ✅ Default to false

  runApp(ChangeNotifierProvider(create: (context)=> StorageService(),
  child:MyApp(seenOnboarding: seenOnboarding) ,));//
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: seenOnboarding ? AuthPage() : OnboardingWrapper(),
    );
  }
}

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  _OnboardingWrapperState createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("seenOnboarding", true);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onDone: () async {
        await _markOnboardingSeen();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      },
    );
  }
}
