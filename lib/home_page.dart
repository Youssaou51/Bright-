import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post.dart';
import 'comments_page.dart';
import 'user.dart' as AppUser;

class HomePage extends StatefulWidget {
  final List<Post> posts;
  final AppUser.User currentUser;
  final Future<void> Function() refreshPosts;
  final Set<String> likedPostIds;

  const HomePage({
    Key? key,
    required this.posts,
    required this.currentUser,
    required this.likedPostIds,
    required this.refreshPosts,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late SupabaseClient _supabase;
  late Set<String> _likedPostIds;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _likedPostIds = Set.from(widget.likedPostIds);
    _loadInitialLikes();
  }

  Future<void> _loadInitialLikes() async {
    try {
      final response = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id);
      print('Load initial likes response: $response');
      setState(() {
        _likedPostIds = response.map<String>((like) => like['post_id'] as String).toSet();
      });
    } catch (e) {
      print('Error loading initial likes: $e');
    }
  }

  Future<void> _toggleLike(Post post) async {
    final userId = widget.currentUser.id;
    final isLiked = _likedPostIds.contains(post.id);

    try {
      if (isLiked) {
        await _supabase
            .from('likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', userId);
        print('Delete like for post ${post.id} by user $userId');
        setState(() {
          _likedPostIds.remove(post.id);
        });
      } else {
        await _supabase.from('likes').insert({
          'post_id': post.id,
          'user_id': userId,
        });
        print('Insert like for post ${post.id} by user $userId');
        setState(() {
          _likedPostIds.add(post.id);
        });
      }
      // Délai pour propagation
      await Future.delayed(const Duration(seconds: 1));
      try {
        await widget.refreshPosts();
        print('refreshPosts called successfully');
      } catch (e) {
        print('Error refreshing posts: $e');
      }
    } catch (e) {
      print('Error toggling like for post ${post.id}: $e');
      String errorMessage = 'Erreur lors du like/désaimage.';
      if (e.toString().contains('violates row-level security policy')) {
        errorMessage = 'Erreur : Permissions insuffisantes pour aimer/supprimer le like.';
      } else if (e.toString().contains('foreign key constraint') || e.toString().contains('23503')) {
        errorMessage = 'Erreur : Publication ou utilisateur non trouvé.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      // Revenir à l'état initial
      setState(() {
        if (isLiked) {
          _likedPostIds.add(post.id);
        } else {
          _likedPostIds.remove(post.id);
        }
      });
    }
  }

  void _showCommentsPage(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsPage(post: post, currentUser: widget.currentUser),
    );
  }

  Widget _buildPostItem(Post post) {
    final isLiked = _likedPostIds.contains(post.id);
    final hasImages = post.images.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            leading: CircleAvatar(
              backgroundImage: NetworkImage(post.profilePicture),
              radius: 24,
            ),
            title: Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatDate(post.timestamp), style: TextStyle(color: Colors.grey.shade600)),
          ),
          if (hasImages)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 280,
                child: PageView.builder(
                  itemCount: post.images.length,
                  itemBuilder: (context, index) => Image.network(
                    post.images[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Text(post.caption, style: const TextStyle(fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : Colors.grey.shade800,
                  ),
                  onPressed: () => _toggleLike(post),
                ),
                Text(post.likesCount.toString()),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () => _showCommentsPage(post),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {}, // À implémenter
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sortedPosts = [...widget.posts]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return RefreshIndicator(
      onRefresh: widget.refreshPosts,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: sortedPosts.length,
        itemBuilder: (context, index) => _buildPostItem(sortedPosts[index]),
      ),
    );
  }
}