import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post.dart';
import 'comments_page.dart';
import 'user.dart' as AppUser;

class HomePage extends StatefulWidget {
  final List<Post> posts;
  final AppUser.User currentUser;
  final Future<void> Function() refreshPosts;

  const HomePage({
    Key? key,
    required this.posts,
    required this.currentUser,
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
    _supabase = Supabase.instance.client; // Initialize the Supabase client
    _likedPostIds = {};
    _loadInitialLikes();
  }

  Future<void> _loadInitialLikes() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('id, liked_by')
          .not('liked_by', 'is', null);

      if (response != null) {
        setState(() {
          _likedPostIds.addAll(
            response.where((post) {
              final likedByStr = post['liked_by'] as String? ?? '';
              return likedByStr.contains(widget.currentUser.id);
            }).map((post) => post['id'].toString()),
          );
        });
      }
    } catch (e) {
      print('Error loading initial likes: $e');
    }
  }

  Future<void> _toggleLike(Post post) async {
    final isLiked = _likedPostIds.contains(post.id);
    if (isLiked) return;

    final newLikesCount = post.likesCount + 1;
    final newLikedBy = '${post.likedBy.join(',')}${post.likedBy.isNotEmpty ? ',' : ''}${widget.currentUser.id}';

    // Optimistic update
    setState(() {
      _likedPostIds.add(post.id);
      post.likesCount = newLikesCount;
      post.likedBy.add(widget.currentUser.id);
    });

    try {
      await _supabase
          .from('posts')
          .update({
        'likes_count': newLikesCount,
        'liked_by': newLikedBy,
      })
          .eq('id', post.id);
    } catch (e) {
      // Revert on error
      setState(() {
        _likedPostIds.remove(post.id);
        post.likesCount--;
        post.likedBy.remove(widget.currentUser.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to like post. Please try again.')));
    }
  }

  void _showCommentsPage(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsPage(post: post, currentUser: widget.currentUser),
    );
  }

  Widget _buildPostItem(Post post) {
    final isLiked = _likedPostIds.contains(post.id);
    final hasImages = post.images.isNotEmpty;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(post.profilePicture)),
            title: Text(post.username, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatDate(post.timestamp), style: TextStyle(color: Colors.grey)),
          ),
          if (hasImages)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: post.images.length,
                itemBuilder: (context, index) => Image.network(post.images[index], fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          Padding(padding: EdgeInsets.all(12.0), child: Text(post.caption)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black),
                  onPressed: () => _toggleLike(post),
                ),
                Text(post.likesCount.toString()),
                SizedBox(width: 16),
                IconButton(icon: Icon(Icons.comment), onPressed: () => _showCommentsPage(post)),
                Spacer(),
                IconButton(icon: Icon(Icons.share), onPressed: () {},), // Implement share functionality
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
        padding: EdgeInsets.symmetric(vertical: 8.0),
        itemCount: sortedPosts.length,
        itemBuilder: (context, index) => _buildPostItem(sortedPosts[index]),
      ),
    );
  }
}