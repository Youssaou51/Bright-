import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _client = Supabase.instance.client;

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Initialise les notifications locales
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print("📩 Notification clicked: ${details.payload}");
      },
    );
  }

  /// Affiche une notification locale
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'default_channel_id',
      'Default',
      channelDescription: 'Notifications locales par défaut',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'notification_payload',
    );
  }

  /// Écoute les nouveaux posts et commentaires en temps réel (autres utilisateurs seulement)
  static void listenToSupabaseRealtime(String currentUserId) {
    // 🔔 Nouveau post
    final postChannel = _client.channel('posts_changes');

    postChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'posts',
      callback: (payload) {
        final newPost = payload.newRecord;
        if (newPost != null && newPost['user_id'] != currentUserId) {
          print("📩 Nouveau post d’un autre utilisateur détecté !");
          showLocalNotification(
            title: "Nouveau post",
            body: "Un utilisateur a publié un nouveau contenu.",
          );
        }
      },
    );

    // 💬 Nouveau commentaire
    final commentChannel = _client.channel('comments_changes');

    commentChannel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'comments',
      callback: (payload) {
        final newComment = payload.newRecord;
        if (newComment != null && newComment['user_id'] != currentUserId) {
          print("💬 Nouveau commentaire d’un autre utilisateur détecté !");
          showLocalNotification(
            title: "Nouveau commentaire",
            body: "Un utilisateur a ajouté un commentaire.",
          );
        }
      },
    );

    // 🎯 Abonnement
    postChannel.subscribe();
    commentChannel.subscribe();
  }
}
