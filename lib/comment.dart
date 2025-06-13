class Comment {
  final int id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String profilePicture;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.profilePicture,
  });

  // 👇 C'est ici que tu colles ta méthode
  factory Comment.fromMap(Map<String, dynamic> map) {
    final userMap = map['users'] ?? {};
    return Comment(
      id: map['id'],
      postId: map['post_id'],
      userId: map['user_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      username: userMap['username'] ?? 'Utilisateur',
      profilePicture: userMap['profile_picture'] ?? '',
    );
  }
}
