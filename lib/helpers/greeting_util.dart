import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

String getTimeBasedGreeting(User? user, BuildContext context) {
  final hour = DateTime.now().hour;
  final firstName = getUserFirstName(user);
  final l10n = AppLocalizations.of(context)!;

  List<String> greetings;

  if (hour >= 5 && hour < 12) {
    greetings = [
      l10n.morningGreeting1(firstName),
      l10n.morningGreeting2(firstName),
      l10n.morningGreeting3(firstName),
      l10n.morningGreeting4(firstName),
    ];
  } else if (hour >= 12 && hour < 18) {
    greetings = [
      l10n.afternoonGreeting1(firstName),
      l10n.afternoonGreeting2(firstName),
      l10n.afternoonGreeting3(firstName),
      l10n.afternoonGreeting4(firstName),
    ];
  } else if (hour >= 18 && hour < 22) {
    greetings = [
      l10n.eveningGreeting1(firstName),
      l10n.eveningGreeting2(firstName),
      l10n.eveningGreeting3(firstName),
      l10n.eveningGreeting4(firstName),
    ];
  } else {
    greetings = [
      l10n.nightGreeting1(firstName),
      l10n.nightGreeting2(firstName),
      l10n.nightGreeting3(firstName),
      l10n.nightGreeting4(firstName),
    ];
  }

  return greetings[DateTime.now().millisecond % greetings.length]
      .replaceAll('{name}', firstName);
}
String getUserFirstName(User? user) {
  if (user != null && user.email != null) {
    return getFirstNameFromEmail(user.email!);
  }
  return '';
}

String getFirstNameFromEmail(String email) {
  if (email.contains('@')) {
    String username = email.split('@')[0];
    return username.split('.').first.capitalize();
  }
  return email;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

