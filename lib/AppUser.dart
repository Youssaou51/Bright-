import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String id;
  final String email;
  final String? username;
  final String? avatarUrl;

  AppUser.fromSupabaseUser(User user) :
        id = user.id,
        email = user.email ?? '',
        username = user.userMetadata?['username'] ?? user.email?.split('@').first,
        avatarUrl = user.userMetadata?['avatar_url'];
}