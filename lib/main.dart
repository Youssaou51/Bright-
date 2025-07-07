import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'user.dart' as local;
import 'post.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lupyveilvgzkolbeimlg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1cHl2ZWlsdmd6a29sYmVpbWxnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjQ3OTc2MiwiZXhwIjoyMDU4MDU1NzYyfQ.v581oYh0hMCO7daGEZW_pcAgq32vpT3vQ5U445A0nek',
  );

  // Recover session with stored refresh token
  final prefs = await SharedPreferences.getInstance();
  final refreshToken = prefs.getString('refreshToken');
  if (refreshToken != null) {
    try {
      await Supabase.instance.client.auth.recoverSession(refreshToken);
    } catch (e) {
      print('Failed to recover session: $e');
    }
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      final existing = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await Supabase.instance.client.from('users').insert({
          'id': user.id,
          'username': user.email?.split('@')[0] ?? 'Anonymous',
          'profile_picture': '',
        });
        print('✅ Nouvel utilisateur ajouté : ${user.email}');
      } else {
        print('👤 Utilisateur existant : ${user.email}');
      }
    } else if (event == AuthChangeEvent.signedOut) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
    }
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = _supabase.auth.currentUser != null || (prefs.getBool('isLoggedIn') ?? false);
    print('Auth status check: isLoggedIn = $isLoggedIn, currentUser = ${_supabase.auth.currentUser}, prefs = ${prefs.getBool('isLoggedIn')}');
    return isLoggedIn ? '/home' : '/login';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BFF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
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
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => FutureBuilder<String?>(
          future: _checkAuthStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final route = snapshot.data;
            if (route == '/home') {
              final user = _supabase.auth.currentUser;
              if (user == null) return LoginPage();
              final currentUser = local.User(
                id: user.id,
                username: user.email?.split('@')[0] ?? 'User',
                pseudo: user.email ?? 'user@bff.com',
                imageUrl: "https://via.placeholder.com/150",
              );
              return HomePage(
                posts: [],
                currentUser: currentUser,
                refreshPosts: () async {},
                likedPostIds: <String>{},
              );
            }
            return LoginPage();
          },
        ),
        '/welcome': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) {
          final user = _supabase.auth.currentUser;
          if (user == null) return WelcomePage();
          final currentUser = local.User(
            id: user.id,
            username: user.email?.split('@')[0] ?? 'User',
            pseudo: user.email ?? 'user@bff.com',
            imageUrl: "https://via.placeholder.com/150",
          );
          return HomePage(
            posts: [],
            currentUser: currentUser,
            refreshPosts: () async {},
            likedPostIds: <String>{},
          );
        },
        '/profile': (context) {
          final user = _supabase.auth.currentUser;
          if (user == null) return WelcomePage();
          final currentUser = local.User(
            id: user.id,
            username: user.email?.split('@')[0] ?? 'User',
            pseudo: user.email ?? 'user@bff.com',
            imageUrl: "https://via.placeholder.com/150",
          );
          return ProfilePage(currentUser: currentUser);
        },
      },
    );
  }
}