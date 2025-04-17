import 'package:firebase_auth/firebase_auth.dart';

String getTimeBasedGreeting(User? user) {
  final hour = DateTime.now().hour;
  final firstName = getUserFirstName(user);
  
  if (hour >= 5 && hour < 12) {
    List<String> morningGreetings = [
      "Good morning, $firstName!",
      "Rise and shine, $firstName!",
      "Hello $firstName, have a wonderful morning!",
      "Morning! Ready for a great day, $firstName?"
    ];
    return morningGreetings[DateTime.now().millisecond % morningGreetings.length];
  } 

  else if (hour >= 12 && hour < 18) {
    List<String> afternoonGreetings = [
      "Good afternoon, $firstName!",
      "Hey there $firstName, having a good day?",
      "Afternoon, $firstName!",
      "Hope your day is going well, $firstName!"
    ];
    return afternoonGreetings[DateTime.now().millisecond % afternoonGreetings.length];
  } 

  else if (hour >= 18 && hour < 22) {
    List<String> eveningGreetings = [
      "Good evening, $firstName!",
      "Evening, $firstName! How was your day?",
      "Hi $firstName, enjoying your evening?",
      "Winding down, $firstName?"
    ];
    return eveningGreetings[DateTime.now().millisecond % eveningGreetings.length];
  } 

  else {
    List<String> nightGreetings = [
      "Hello night owl, $firstName!",
      "Working late, $firstName?",
      "Good night, $firstName!",
      "Still up, $firstName? Don't forget to rest!"
    ];
    return nightGreetings[DateTime.now().millisecond % nightGreetings.length];
  }
}

String getUserFirstName(User? user) {
  String firstName = "";
  if (user != null && user.email != null) {
    firstName = getFirstNameFromEmail(user.email!);
  }
  return firstName;
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