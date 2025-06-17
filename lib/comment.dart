class Comment {
  final int id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String? profilePicture;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.username,
    this.profilePicture,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    final userMap = map['users'] ?? {};
    return Comment(
      id: map['id'] as int,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      username: userMap['username'] as String? ?? 'Utilisateur anonyme',
      profilePicture: userMap['profile_picture'] as String?,
    );
  }
}