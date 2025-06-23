import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'comment.dart';
import 'post.dart';
import 'user.dart' as AppUser;

class CommentsPage extends StatefulWidget {
  final Post post;
  final AppUser.User currentUser;

  const CommentsPage({
    Key? key,
    required this.post,
    required this.currentUser,
  }) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _supabase
          .from('comments')
          .select('''
            id, post_id, user_id, content, created_at,
            users:users!user_id(username, profile_picture)
          ''')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      setState(() {
        _comments = (response as List<dynamic>)
            .map((map) => Comment.fromMap(map as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur de chargement des commentaires : $e';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      await _supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': widget.currentUser.id,
        'content': content,
      });

      _commentController.clear();

      setState(() {
        widget.post.commentCount++;
      });

      await _loadComments();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commentaire ajouté')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout du commentaire : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _supabase.from('comments').delete().eq('id', commentId);

      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        widget.post.commentCount--;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commentaire supprimé')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de suppression : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteComment(Comment comment) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le commentaire'),
        content: const Text('Voulez-vous vraiment supprimer ce commentaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(comment.id as String);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///') || url.contains('via.placeholder.com')) return false;
    return Uri.tryParse(url)?.hasAuthority ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollSheetController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('Commentaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _comments.isEmpty
                    ? const Center(child: Text('Aucun commentaire pour l\'instant'))
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    final isOwner = comment.userId == widget.currentUser.id;

                    return GestureDetector(
                      onLongPress: isOwner
                          ? () => _confirmDeleteComment(comment)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: _isValidUrl(comment.profilePicture)
                                  ? NetworkImage(comment.profilePicture!)
                                  : null,
                              child: !_isValidUrl(comment.profilePicture)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.username,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeago.format(comment.createdAt, locale: 'fr'),
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(comment.content),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Ajouter un commentaire...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF1E88E5)),
                        onPressed: _addComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
