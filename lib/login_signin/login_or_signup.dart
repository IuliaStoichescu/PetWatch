import 'package:flutter/material.dart';
import 'package:pet_watch/login_signin/login_page.dart';
import 'package:pet_watch/login_signin/signin_page.dart';

class LoginOrSignup extends StatefulWidget {
  const LoginOrSignup({super.key});

  @override
  State<LoginOrSignup> createState() => _LoginOrSignupState();
}

class _LoginOrSignupState extends State<LoginOrSignup> {
  bool loginUp = true;

  void changePage() {
    setState(() {
      loginUp = !loginUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500), 
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation, 
          child: child,
        );
      },
      child: loginUp
          ? LoginPage(
              key: const ValueKey(1), // Ensures widget identity change
              onTap: changePage,
            )
          : SigninPage(
              key: const ValueKey(2), // Ensures widget identity change
              onTap: changePage,
            ),
    );
  }
}
