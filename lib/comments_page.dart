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
  final ScrollController _scrollController = ScrollController();
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
          .select('*')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      setState(() {
        comments = (response as List).cast<Map<String, dynamic>>();
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
      final response = await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': widget.currentUser.id,
        'username': widget.currentUser.username,
        'profile_picture': widget.currentUser.imageUrl,
        'comment_text': commentText,
      });

      if (response.error != null) {
        throw Exception('Error adding comment: ${response.error!.message}');
      }

      _commentController.clear();
      await _fetchComments(); // Fetch comments to update the list
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
        appBar: AppBar(title: Text('Comments')),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _isLoading
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
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return _CommentBlock(
                            username: comment['username'],
                            text: comment['comment_text'],
                            avatarUrl: comment['profile_picture'],
                            isCurrentUser: comment['user_id'] == widget.currentUser.id,
                          );
                        },
                      ),
                    ],
                  ),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              backgroundImage: NetworkImage(avatarUrl),
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
              backgroundImage: NetworkImage(avatarUrl),
            ),
        ],
      ),
    );
  }
}