import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'home_page.dart'; // Import your HomePage
import 'profile_page.dart'; // Import your ProfilePage
import 'post.dart'; // Import your Post model
import 'login_page.dart'; // Import your LoginPage
import 'signup_page.dart'; // Import your SignupPage
import 'user.dart'; // Import your User model

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My White App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomePage(),
        '/home': (context) {
          User currentUser = User(
            username: "DummyUser", // Replace with actual user data
            pseudo: "DummyPseudo", // Replace with actual user data
            imageUrl: "https://via.placeholder.com/150", // Default image URL
          );
          return HomePage(posts: [], currentUser: currentUser); // Pass the currentUser
        },
        '/profile': (context) {
          // You need to get the currentUser from somewhere, possibly from a provider or the HomePage context
          User currentUser = User(
            username: "DummyUser", // Replace with the actual user data
            pseudo: "DummyPseudo", // Replace with the actual user data
            imageUrl: "https://via.placeholder.com/150", // Default image URL
          );
          return ProfilePage(currentUser: currentUser); // Pass the currentUser
        },
      },
    );
  }
}