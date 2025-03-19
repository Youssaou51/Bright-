import 'dart:io'; // For File handling

class Comment {
  final String username;
  final String userImageUrl;
  final String content;
  final DateTime timestamp;

  Comment({
    required this.username,
    required this.userImageUrl,
    required this.content,
    required this.timestamp,
  });
}

