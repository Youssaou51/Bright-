import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
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
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 5));

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
          content: Text('Erreur lors de la suppression : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _confirmDelete(Comment comment) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer ce commentaire ?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Cette action est irréversible.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            child: Text('Annuler', style: GoogleFonts.poppins(color: Color(0xFF1976D2))),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Supprimer', style: GoogleFonts.poppins(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteComment(comment.id as String);
            },
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollSheetController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Text(
                  'Commentaires',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Divider(),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
                      : _error != null
                      ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
                      : _comments.isEmpty
                      ? Center(
                    child: Text(
                      'Aucun commentaire pour l\'instant',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final isOwner = comment.userId == widget.currentUser.id;

                      return GestureDetector(
                        onTap: isOwner ? () => _confirmDelete(comment) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _isValidUrl(comment.profilePicture)
                                    ? NetworkImage(comment.profilePicture!)
                                    : null,
                                child: !_isValidUrl(comment.profilePicture)
                                    ? const Icon(Icons.person, color: Colors.grey)
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
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          timeago.format(comment.createdAt, locale: 'fr'),
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment.content,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
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
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}