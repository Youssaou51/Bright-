import 'dart:convert';

class Post {
  final String id;
  final String username;
  final String? profilePicture;
  final String? caption;
  final List<String> imageUrls; // Renamed to imageUrls for clarity
  final List<String> videoUrls; // Added videoUrls field
  final int likesCount;
  int commentCount;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.username,
    this.profilePicture,
    this.caption,
    required this.imageUrls,
    required this.videoUrls, // Added required parameter
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
      imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [], // Mapped as imageUrls
      videoUrls: (json['video_urls'] as List<dynamic>?)?.cast<String>() ?? [], // Added mapping for video_urls
      likesCount: json['likes_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'profile_picture': profilePicture,
      'caption': caption,
      'image_urls': imageUrls,
      'video_urls': videoUrls, // Included in toJson for potential future use
      'likes_count': likesCount,
      'comment_count': commentCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}