import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_watch/login_signin/auth_page.dart';
import 'package:pet_watch/login_signin/services/storage_service.dart';
import 'package:pet_watch/map_logic/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_watch/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


Future<void> main() async {
  await dotenv.load(fileName: ".env");
  final apiKeyWeb = dotenv.env['API_KEY_WEB'];
  WidgetsFlutterBinding.ensureInitialized(); // Ensure async code runs before UI
  NotificationService().initNotification();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKeyWeb!,
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
  final bool seenOnboarding = prefs.getBool("seenOnboarding") ?? false; // Default to false

  runApp(ChangeNotifierProvider(create: (context)=> StorageService(),
  child:LocaleWrapper(seenOnboarding: seenOnboarding) ,));//
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  final Locale locale;
  final void Function(Locale) onLocaleChange;

  const MyApp({
    super.key,
    required this.seenOnboarding,
    required this.locale,
    required this.onLocaleChange,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ro')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
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
          MaterialPageRoute(builder: (context) => AuthPage()),
        );
      },
    );
  }
}
class LocaleWrapper extends StatefulWidget {
  final bool seenOnboarding;
  const LocaleWrapper({super.key, required this.seenOnboarding});

  @override
  State<LocaleWrapper> createState() => LocaleWrapperState();
}

class LocaleWrapperState extends State<LocaleWrapper> {
  Locale _locale = const Locale('en');

  void setLocale(Locale newLocale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("appLocale", newLocale.languageCode);
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  void _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString("appLocale") ?? "en";
    setState(() {
      _locale = Locale(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyApp(
      seenOnboarding: widget.seenOnboarding,
      locale: _locale,
      onLocaleChange: setLocale,
    );
  }
}

