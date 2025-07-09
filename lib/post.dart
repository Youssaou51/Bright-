import 'dart:convert'; // Garder si vous l'utilisez ailleurs, sinon il peut être retiré

class Post {
  final String id;
  final String userId; // Added userId field to match the posts table
  final String username;
  final String? profilePicture;
  final String? caption;
  final List<String> imageUrls;
  final List<String> videoUrls;
  int likesCount; // Rendu mutable pour la mise à jour locale
  int commentCount; // Rendu mutable pour la mise à jour locale
  final DateTime timestamp;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.profilePicture,
    this.caption,
    required this.imageUrls,
    required this.videoUrls,
    required this.likesCount,
    required this.commentCount,
    required this.timestamp,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String, // Map to user_id from the database
      username: json['username'] as String,
      profilePicture: json['profile_picture'] as String?,
      caption: json['caption'] as String?,
      // S'assurer que 'image_urls' et 'video_urls' sont bien des listes de chaînes de caractères
      imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      videoUrls: (json['video_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      // Les noms des clés ici doivent correspondre EXACTEMENT à ceux retournés par votre requête SELECT de Supabase
      // C'est pourquoi j'avais spécifié 'likes_count' et 'comment_count' dans la requête
      likesCount: json['likes_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId, // Include user_id in the JSON output
      'username': username,
      'profile_picture': profilePicture,
      'caption': caption,
      'image_urls': imageUrls,
      'video_urls': videoUrls,
      'likes_count': likesCount,
      'comment_count': commentCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}