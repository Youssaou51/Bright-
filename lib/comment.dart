class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String profilePicture;
  final String commentText;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.profilePicture,
    required this.commentText,
    required this.timestamp,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      username: json['username'],
      profilePicture: json['profile_picture'],
      commentText: json['comment_text'],
      timestamp: DateTime.parse(json['created_at']),
    );
  }
}