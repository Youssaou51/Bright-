import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'home_page.dart'; // Import your HomePage
import 'profile_page.dart'; // Import your ProfilePage
import 'post.dart'; // Import your Post model
import 'login_page.dart'; // Import your LoginPage
import 'signup_page.dart'; // Import your SignupPage
import 'user.dart' as local; // Alias for your local User class
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lupyveilvgzkolbeimlg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1cHl2ZWlsdmd6a29sYmVpbWxnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0Nzk3NjIsImV4cCI6MjA1ODA1NTc2Mn0.7DtO-oZisVK-RMCbhQy9uAGr00JjbMotdcjCu-dPB7E',
  );
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
          local.User currentUser = local.User(
            username: "DummyUser", // Replace with actual user data
            pseudo: "DummyPseudo", // Replace with actual user data
            imageUrl: "https://via.placeholder.com/150", // Default image URL
          );
          return HomePage(posts: [], currentUser: currentUser); // Pass the currentUser
        },
        '/profile': (context) {
          local.User currentUser = local.User(
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