import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsPage extends StatefulWidget {
  final List<Comment> comments; // List of comments to display
  final String postId; // ID of the post being commented on
  final SupabaseClient supabaseClient; // Supabase client for database operations
  final AppUser.User currentUser; // Current user information

  CommentsPage({
    Key? key,
    required this.comments,
    required this.postId,
    required this.supabaseClient,
    required this.currentUser,
  }) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.comments.length,
                itemBuilder: (context, index) {
                  final comment = widget.comments[index];
                  return _buildCommentItem(comment);
                },
              ),
            ),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(comment.profilePicture),
              radius: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    comment.commentText,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTimestamp(comment.timestamp),
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: () {
              _addComment(_commentController.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addComment(String commentText) async {
    if (commentText.isEmpty) return;

    try {
      final response = await widget.supabaseClient.from('comments').insert({
        'post_id': widget.postId, // Ensure this is UUID type
        'user_id': widget.currentUser.id, // Ensure this is UUID type
        'username': widget.currentUser.username,
        'profile_picture': widget.currentUser.imageUrl,
        'comments': commentText,
      }).execute();

      if (response.error != null) {
        throw Exception('Failed to add comment: ${response.error!.message}');
      }

      // Optionally update the UI or state after adding a comment
      setState(() {
        widget.comments.add(Comment(
          id: response.data[0]['id'], // Assuming the response returns the new comment ID
          postId: widget.postId,
          userId: widget.currentUser.id,
          username: widget.currentUser.username,
          profilePicture: widget.currentUser.imageUrl,
          commentText: commentText,
          timestamp: DateTime.now(),
        ));
      });

      _commentController.clear(); // Clear the text field after submission
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}