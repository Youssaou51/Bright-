import 'dart:convert';

class Post {
  final String id;
  final String userId;
  final String username;
  final String profilePicture;
  final String caption;
  final List<String> images;
  final List<String> videos;
  final int likesCount;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.profilePicture,
    required this.caption,
    this.images = const [],
    this.videos = const [],
    required this.likesCount,
    required this.timestamp,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      if (data is String) {
        try {
          final parsed = jsonDecode(data) as List<dynamic>;
          return parsed.map((e) => e.toString()).toList();
        } catch (e) {
          return data
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      return [];
    }

    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      profilePicture: json['profile_picture'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      images: parseList(json['image_urls']),
      videos: parseList(json['video_urls']),
      likesCount: (json['likes_count'] as int?) ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'profile_picture': profilePicture,
      'caption': caption,
      'image_urls': images,
      'video_urls': videos,
      'likes_count': likesCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}