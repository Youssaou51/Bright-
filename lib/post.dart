import 'dart:convert';

class Post {
  final String id;
  final String username;
  final String? profilePicture;
  final String? caption;
  final List<String> images;
  final int likesCount;
  int commentCount;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.username,
    this.profilePicture,
    this.caption,
    required this.images,
    required this.likesCount,
    required this.commentCount,
    required this.timestamp,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      username: json['username'] as String,
      profilePicture: json['profile_picture'] as String?,
      caption: json['caption'] as String?,
      images: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}