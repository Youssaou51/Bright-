import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'welcome_page.dart';
import 'dashboard_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'user.dart' as local;
import 'splash_screen.dart';

/// 🔔 Handler pour les notifications reçues en arrière-plan
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("📩 [Background] Notification: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrightFutureApp());
}

class BrightFutureApp extends StatefulWidget {
  const BrightFutureApp({Key? key}) : super(key: key);

  @override
  State<BrightFutureApp> createState() => _BrightFutureAppState();
}

class _BrightFutureAppState extends State<BrightFutureApp> {
  bool _isInitialized = false;
  local.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 🟢 Init Firebase (pour les notifications)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // 🟣 Init Supabase
    await Supabase.initialize(
      url: 'https://lupyveilvgzkolbeimlg.supabase.co',
      anonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1cHl2ZWlsdmd6a29sYmVpbWxnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjQ3OTc2MiwiZXhwIjoyMDU4MDU1NzYyfQ.v581oYh0hMCO7daGEZW_pcAgq32vpT3vQ5U445A0nek',
    );

    // 🔔 Init des notifications locales
    await NotificationService.initialize();

    // 🔁 Restauration de session (si token enregistré)
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken != null) {
      try {
        await Supabase.instance.client.auth.recoverSession(refreshToken);
        print('🔁 Session restaurée.');
      } catch (e) {
        print('⚠️ Erreur de restauration de session : $e');
      }
    }

    // 👤 Vérification de l'utilisateur connecté
    final user = Supabase.instance.client.auth.currentUser;

    // 💡 Si un utilisateur est connecté → création du modèle local
    if (user != null) {
      _currentUser = local.User(
        id: user.id,
        username: user.email?.split('@')[0] ?? 'User',
        pseudo: user.email ?? 'user@bff.com',
        imageUrl: "https://via.placeholder.com/150",
      );

      // 🔔 Écoute en temps réel des nouveaux posts (sauf ceux de l'utilisateur actuel)
      NotificationService.setupRealtimeListeners(user.id); // ✅ Correct method name
    }

    // ✅ Fin d'initialisation
    setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bright Future App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: !_isInitialized
          ? const SplashScreen(nextScreen: null)
          : (_currentUser != null
          ? DashboardPage(currentUser: _currentUser!)
          : const WelcomePage()),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/dashboard': (context) => _currentUser != null
            ? DashboardPage(currentUser: _currentUser!)
            : const WelcomePage(),
        '/profile': (context) => _currentUser != null
            ? ProfilePage(currentUser: _currentUser!)
            : const WelcomePage(),
      },
    );
  }
}