import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _client = Supabase.instance.client;
  static final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Store channel references
  static RealtimeChannel? _postChannel;
  static RealtimeChannel? _commentChannel;
  static RealtimeChannel? _reportChannel;

  /// Initialize local notifications
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print("📩 Notification clicked: ${details.payload}");
        _handleNotificationClick(details.payload);
      },
    );
  }

  static void _handleNotificationClick(String? payload) {
    if (payload != null) {
      print("Notification payload: $payload");
    }
  }

  /// Show local notification
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Setup realtime listeners for database changes
  static void setupRealtimeListeners(String currentUserId) {
    print("🔔 Setting up realtime listeners for user: $currentUserId");

    // Remove existing listeners first
    removeListeners();

    // Posts listener
    _postChannel = _client.channel('posts_channel');
    _postChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'posts',
      callback: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord != null && newRecord['user_id'] != currentUserId) {
          print('📩 New post from other user: ${newRecord['id']}');
          await _callNotificationFunction('posts', newRecord);

          // Also show local notification
          await showLocalNotification(
            title: "Nouveau post",
            body: "Un utilisateur a publié un nouveau contenu",
            payload: 'post_${newRecord['id']}',
          );
        }
      },
    ).subscribe();

    // Comments listener
    _commentChannel = _client.channel('comments_channel');
    _commentChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'comments',
      callback: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord != null && newRecord['user_id'] != currentUserId) {
          print('💬 New comment from other user: ${newRecord['id']}');
          await _callNotificationFunction('comments', newRecord);

          // Also show local notification
          await showLocalNotification(
            title: "Nouveau commentaire",
            body: "Un utilisateur a commenté",
            payload: 'comment_${newRecord['id']}',
          );
        }
      },
    ).subscribe();

    // Reports listener
    _reportChannel = _client.channel('reports_channel');
    _reportChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'reports',
      callback: (payload) async {
        final newRecord = payload.newRecord;
        if (newRecord != null && newRecord['user_id'] != currentUserId) {
          print('📄 New report from other user: ${newRecord['id']}');
          await _callNotificationFunction('reports', newRecord);

          // Also show local notification
          await showLocalNotification(
            title: "Nouveau rapport",
            body: "Un nouveau rapport a été ajouté",
            payload: 'report_${newRecord['id']}',
          );
        }
      },
    ).subscribe();

    print("✅ Realtime listeners setup complete");
  }

  /// Call the edge function to send push notifications
  static Future<void> _callNotificationFunction(
      String table,
      Map<String, dynamic> record,
      ) async {
    try {
      print("📡 Calling edge function for table: $table");

      final response = await _client.functions.invoke(
        'sendNotification',
        body: {
          'table': table,
          'record': record,
          'type': 'insert',
        },
      );

      print('✅ Edge function response: $response');
    } catch (e) {
      print('❌ Error calling edge function: $e');
    }
  }

  /// Remove all listeners
  static void removeListeners() {
    try {
      if (_postChannel != null) {
        _client.removeChannel(_postChannel!);
        _postChannel = null;
      }
      if (_commentChannel != null) {
        _client.removeChannel(_commentChannel!);
        _commentChannel = null;
      }
      if (_reportChannel != null) {
        _client.removeChannel(_reportChannel!);
        _reportChannel = null;
      }
      print("🔕 All listeners removed");
    } catch (e) {
      print("Error removing listeners: $e");
    }
  }

  /// Alternative: unsubscribe using the channel's unsubscribe method
  static void unsubscribeAll() {
    try {
      _postChannel?.unsubscribe();
      _commentChannel?.unsubscribe();
      _reportChannel?.unsubscribe();

      _postChannel = null;
      _commentChannel = null;
      _reportChannel = null;

      print("🔕 All channels unsubscribed");
    } catch (e) {
      print("Error unsubscribing: $e");
    }
  }
}