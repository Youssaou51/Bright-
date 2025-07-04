import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
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

  // Ajout automatique de l'utilisateur dans la table 'users' après connexion
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      final user = session.user;
      if (user == null) return;

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
        if (kDebugMode) dev.log('✅ Nouvel utilisateur ajouté : ${user.email}');
      } else {
        if (kDebugMode) dev.log('👤 Utilisateur existant : ${user.email}');
      }
    }
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    // Écoute les changements d'auth pour mettre à jour l'état de connexion
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      setState(() {
        _isLoggedIn = event == AuthChangeEvent.signedIn;
      });
    });
  }

  void _checkSession() async {
    final session = _supabase.auth.currentSession;
    setState(() {
      _isLoggedIn = session != null;
      _isLoading = false;
    });

    if (session != null) {
      // User is logged in, navigate to HomePage
      // Ensure context is available before navigating
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
      // Conditionally set initialRoute based on login state
      initialRoute: _isLoggedIn ? '/home' : '/',
      routes: {
        '/': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) {
          final user = _supabase.auth.currentUser;
          final currentUser = local.User(
            id: user?.id ?? '',
            username: user?.email?.split('@')[0] ?? 'User',
            pseudo: user?.email ?? 'user@bff.com',
            imageUrl: "https://via.placeholder.com/150",
          );
          return HomePage(
            posts: [],
            currentUser: currentUser,
            refreshPosts: () async {
              if (kDebugMode) dev.log('🔄 Rafraîchissement des posts...');
            },
            likedPostIds: <String>{},
          );
        },
        '/profile': (context) {
          final user = _supabase.auth.currentUser;
          final currentUser = local.User(
            id: user?.id ?? '',
            username: user?.email?.split('@')[0] ?? 'User',
            pseudo: user?.email ?? 'user@bff.com',
            imageUrl: "https://via.placeholder.com/150",
          );
          return ProfilePage(currentUser: currentUser);
        },
      },
    );
  }
}
