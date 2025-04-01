import 'dart:convert';

class Post {
  final String id;
  final String userId;
  final String username;
  final String profilePicture;
  final String caption;
  final List<String> images;
  final List<String> videos;
  int likesCount;
  List<String> likedBy;
  final List<Map<String, dynamic>> comments;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.profilePicture,
    required this.caption,
    this.images = const [],
    this.videos = const [],
    this.likesCount = 0,
    this.likedBy = const [],
    this.comments = const [],
    required this.timestamp,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse lists
    List<String> parseList(dynamic data) {
      if (data == null) return [];
      if (data is List) return data.map((e) => e.toString()).toList();
      if (data is String) {
        try {
          // Handle JSON-encoded strings
          final parsed = jsonDecode(data) as List<dynamic>;
          return parsed.map((e) => e.toString()).toList();
        } catch (e) {
          // Handle comma-separated strings
          return data.split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      return [];
    }

    return Post(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      username: json['username'].toString(),
      profilePicture: json['profile_picture'].toString(),
      caption: json['caption'].toString(),
      images: parseList(json['image_urls']),
      videos: parseList(json['video_urls']),
      likesCount: (json['likes_count'] as int?) ?? 0,
      likedBy: parseList(json['liked_by']),
      comments: (json['comments'] is List)
          ? (json['comments'] as List).cast<Map<String, dynamic>>()
          : [],
      timestamp: DateTime.parse(json['timestamp'].toString()),
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
      'liked_by': likedBy.join(','), // Store as comma-separated string
      'comments': comments,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}