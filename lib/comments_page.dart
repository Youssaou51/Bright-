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
      print('Fetching comments for post_id: ${widget.post.id}');
      final commentsResponse = await _supabase
          .from('comments')
          .select('*, users!fk_user(username, profile_picture)')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      setState(() {
        comments = commentsResponse.map((data) => Comment.fromMap(data)).toList();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur : Impossible de charger les commentaires.')),
      );
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final supabaseUser = _supabase.auth.currentUser;

    if (supabaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté')),
      );
      return;
    }

    try {
      print('Supabase user ID: ${supabaseUser.id}');
      print('Current session: ${_supabase.auth.currentSession}');
      print('Post ID: ${widget.post.id} (type: ${widget.post.id.runtimeType})');
      print('Ensuring user profile for ID: ${supabaseUser.id}');

      // Verify user exists
      final userCheck = await _supabase
          .from('users')
          .select('id, username')
          .eq('id', supabaseUser.id)
          .maybeSingle();
      print('User check result: $userCheck');

      if (userCheck == null) {
        print('User not found, performing upsert');
        await _supabase.from('users').upsert({
          'id': supabaseUser.id,
          'username': supabaseUser.email?.split('@')[0] ?? 'Utilisateur_${supabaseUser.id.hashCode}',
          'profile_picture': '',
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id').then((_) {
          print('User profile created/updated for ID: ${supabaseUser.id}');
        }).catchError((error) {
          print('Upsert error: $error');
          throw Exception('Failed to create/update user profile: $error');
        });
      } else {
        print('User already exists: $userCheck');
      }

      // Verify post exists
      final postCheck = await _supabase
          .from('posts')
          .select('id')
          .eq('id', widget.post.id)
          .maybeSingle();
      print('Post check result: $postCheck');

      if (postCheck == null) {
        throw Exception('Post not found: ${widget.post.id}');
      }

      print('Inserting comment for post_id: ${widget.post.id}, user_id: ${supabaseUser.id}');
      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': supabaseUser.id,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      }).then((_) {
        print('Comment inserted successfully');
      }).catchError((error) {
        print('Comment insert error: $error');
        throw Exception('Failed to insert comment: $error');
      });

      _commentController.clear();
      await _fetchComments();
    } catch (e) {
      print('Error adding comment: $e');
      String errorMessage = 'Erreur : Impossible d’ajouter le commentaire.';
      if (e.toString().contains('violates row-level security policy')) {
        errorMessage = 'Erreur : Permissions insuffisantes pour créer ou mettre à jour le profil ou commentaire.';
      } else if (e.toString().contains('foreign key constraint') || e.toString().contains('23503')) {
        errorMessage = 'Erreur : Utilisateur ou publication non trouvé dans la base de données.';
      } else if (e.toString().contains('invalid input syntax') || e.toString().contains('22P02')) {
        errorMessage = 'Erreur : Type de données incorrect pour la publication.';
      } else if (e.toString().contains('Failed to create/update user profile')) {
        errorMessage = 'Erreur : Impossible de créer ou mettre à jour le profil utilisateur.';
      } else if (e.toString().contains('Failed to insert comment')) {
        errorMessage = 'Erreur : Impossible d’ajouter le commentaire à la publication.';
      } else if (e.toString().contains('Post not found')) {
        errorMessage = 'Erreur : La publication n’existe pas.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      print('Deleting comment with ID: $commentId');
      await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .then((_) {
        print('Comment deleted successfully');
      }).catchError((error) {
        print('Comment delete error: $error');
        throw Exception('Failed to delete comment: $error');
      });

      await _fetchComments();
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur : Impossible de supprimer le commentaire.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Commentaires'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                ? Center(
              child: Text(
                'Aucun commentaire pour l’instant.\nLance la discussion !',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              itemCount: comments.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, index) {
                final comment = comments[index];
                return _CommentCard(
                  comment: comment,
                  isCurrentUser: comment.userId == widget.currentUser.id,
                  onDelete: comment.userId == widget.currentUser.id
                      ? () => _deleteComment(comment.id)
                      : null,
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        color: Colors.grey[100],
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Écris un commentaire…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _addComment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isCurrentUser;
  final VoidCallback? onDelete;

  const _CommentCard({
    required this.comment,
    required this.isCurrentUser,
    this.onDelete,
  });

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comment.username,
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                      ),
                      if (isCurrentUser && onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer le commentaire'),
                                content: const Text('Êtes-vous sûr de vouloir supprimer ce commentaire ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      onDelete!();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
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