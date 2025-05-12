import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'comment.dart';
import 'post.dart';
import 'user.dart' as AppUser;

class CommentsPage extends StatefulWidget {
  final Post post;
  final AppUser.User currentUser;

  const CommentsPage({super.key, required this.post, required this.currentUser});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Comment> comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final commentsResponse = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      final commentsWithUsers = await Future.wait(commentsResponse.map<Future<Comment>>((commentData) async {
        final userId = commentData['user_id'];

        try {
          final userResponse = await _supabase
              .from('users')
              .select('username, profile_picture')
              .eq('id', userId)
              .single();

          return Comment.fromMap({
            ...commentData,
            'users': userResponse,
          });
        } catch (e) {
          // Si l’utilisateur n’existe pas, on retourne quand même le commentaire sans données utilisateur
          return Comment.fromMap({
            ...commentData,
            'users': {'username': 'Utilisateur inconnu', 'profile_picture': ''},
          });
        }
      }));

      setState(() {
        comments = commentsWithUsers;
        _isLoading = false;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print('Error fetching comments: $e');
      setState(() => _isLoading = false);
    }
  }


  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;

    if (supabaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté')),
      );
      return;
    }

    try {
      // Vérifie si l'utilisateur est présent dans la table `users`
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('id', supabaseUser.id)
          .maybeSingle(); // ← évite le PostgrestException

      if (userResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil utilisateur introuvable.')),
        );
        return;
      }

      // Insert le commentaire si l'utilisateur est bien trouvé
      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': supabaseUser.id,
        'content': text,
      });

      _commentController.clear();
      await _fetchComments();
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Comments')),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? Center(
                child: Text(
                  'No comments yet.\nBe the first to comment!',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                itemCount: comments.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return _CommentCard(
                    comment: comment,
                    isCurrentUser: comment.userId == widget.currentUser.id,
                  );
                },
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
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

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isCurrentUser;

  const _CommentCard({required this.comment, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final textColor = isCurrentUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            CircleAvatar(
              radius: 20,
              backgroundImage: comment.profilePicture.isNotEmpty
                  ? NetworkImage(comment.profilePicture)
                  : null,
              child: comment.profilePicture.isEmpty ? const Icon(Icons.person) : null,
            ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: isCurrentUser ? 48 : 12,
                right: isCurrentUser ? 12 : 48,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.username, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 4),
                  Text(comment.content, style: TextStyle(color: textColor)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy • HH:mm').format(comment.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser)
            CircleAvatar(
              radius: 20,
              backgroundImage: comment.profilePicture.isNotEmpty
                  ? NetworkImage(comment.profilePicture)
                  : null,
              child: comment.profilePicture.isEmpty ? const Icon(Icons.person) : null,
            ),
        ],
      ),
    );
  }
}
