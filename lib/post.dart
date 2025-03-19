// lib/post.dart
import 'dart:io'; // For File
import 'comment.dart'; // For Comment model

class Post {
  final List<File> images;
  final List<File> videos; // Ensure this is included
  final String caption;
  final DateTime timestamp;
  int likesCount;
  List<Comment> comments; // Ensure this is included

  Post({
    required this.images,
    required this.videos,
    required this.caption,
    required this.timestamp,
    this.likesCount = 0,
    required this.comments, // Ensure this is a required parameter
  });
}