import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'post.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'user.dart' as local;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lupyveilvgzkolbeimlg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1cHl2ZWlsdmd6a29sYmVpbWxnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjQ3OTc2MiwiZXhwIjoyMDU4MDU1NzYyfQ.v581oYh0hMCO7daGEZW_pcAgq32vpT3vQ5U445A0nek',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BFF',
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
          final currentUser = local.User(
            id: "user_id",
            username: "DummyUser",
            pseudo: "DummyPseudo",
            imageUrl: "https://via.placeholder.com/150",
          );
          return HomePage(
            posts: [],
            currentUser: currentUser,
            refreshPosts: () async {
              // Implement your refresh logic here
              // For now, we'll just print to console
              print('Refreshing posts...');
            },
          );
        },
        '/profile': (context) {
          final currentUser = local.User(
            id: "user_id",
            username: "DummyUser",
            pseudo: "DummyPseudo",
            imageUrl: "https://via.placeholder.com/150",
          );
          return ProfilePage(currentUser: currentUser);
        },
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
      },
    );
  }
}