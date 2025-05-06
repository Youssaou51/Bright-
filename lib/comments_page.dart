import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user.dart' as AppUser;
import 'post.dart';

class CommentsPage extends StatefulWidget {
  final Post post;
  final AppUser.User currentUser;

  const CommentsPage({
    super.key,
    required this.post,
    required this.currentUser,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await _supabase
          .from('comments')
          .select()
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      setState(() {
        comments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': widget.currentUser.id,
        'content': commentText,
      });

      _commentController.clear();
      setState(() {
        comments.add({
          'post_id': widget.post.id,
          'user_id': widget.currentUser.id,
          'content': commentText,
          'users': {
            'username': widget.currentUser.username,
            'profile_picture': widget.currentUser.imageUrl,
          },
        });
      });
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : comments.isEmpty
                    ? Center(
                  child: Text(
                    'No comments yet\nBe the first to comment!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
                    : ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final user = comment['users'];
                    return _CommentBlock(
                      username: user != null
                          ? user['username'] ?? 'Unknown'
                          : 'Unknown',
                      text: comment['content'] ?? '',
                      avatarUrl: user != null
                          ? user['profile_picture'] ?? ''
                          : '',
                      isCurrentUser:
                      comment['user_id'] == widget.currentUser.id,
                    );
                  },
                ),
              ),
            ),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }
}

class _CommentBlock extends StatelessWidget {
  final String username;
  final String text;
  final String avatarUrl;
  final bool isCurrentUser;

  const _CommentBlock({
    required this.username,
    required this.text,
    required this.avatarUrl,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            CircleAvatar(
              radius: 20,
              backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: isCurrentUser ? 48 : 12,
                right: isCurrentUser ? 12 : 48,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser)
            CircleAvatar(
              radius: 20,
              backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
        ],
      ),
    );
  }
}
