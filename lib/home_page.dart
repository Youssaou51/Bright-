import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'post.dart';
import 'comments_page.dart';
import 'user.dart' as AppUser;

class HomePage extends StatefulWidget {
  // These properties are kept as they are part of your existing API,
  // even if 'posts' and 'likedPostIds' are now primarily managed internally.
  final List<Post> posts;
  final AppUser.User currentUser;
  final Future<void> Function() refreshPosts; // Still used for the RefreshIndicator
  final Set<String> likedPostIds;

  const HomePage({
    Key? key,
    required this.posts, // Will be ignored, but kept for API consistency
    required this.currentUser,
    required this.likedPostIds, // Will be used as initial state for _likedPostIds
    required this.refreshPosts, // Still called on pull-to-refresh
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late SupabaseClient _supabase;
  List<Post> _posts = []; // <-- This will hold the fetched posts
  bool _isLoading = true; // State for loading indicator
  String? _errorMessage; // State for displaying errors

  late Set<String> _likedPostIds;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _likedPostIds = Set.from(widget.likedPostIds); // Initialize with passed likes
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    timeago.setLocaleMessages('fr', timeago.FrMessages()); // Set French locale for timeago

    // --- CRUCIAL: Fetch posts when the page initializes ---
    _fetchPosts();
    // -----------------------------------------------------

    _loadInitialLikes(); // Load initial likes for the current user
  }

  // --- NEW: Method to fetch posts from Supabase ---
  Future<void> _fetchPosts() async {
    print('🔄 Starting to fetch posts...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // This query retrieves posts along with their aggregated like and comment counts.
      // Ensure your Supabase RLS policies allow SELECT on 'posts', 'likes', and 'comments'.
      final List<Map<String, dynamic>> response = await _supabase
          .from('posts')
          .select('''
            *,
            likes_count:likes(count),
            comment_count:comments(count)
          ''')
          .order('timestamp', ascending: false)
          .limit(50); // Optional: Limit the number of posts fetched

      print('✅ Raw posts response: $response');

      final List<Post> fetchedPosts = response.map((data) {
        // Extract the aggregated counts, handling potential nulls or empty lists
        final int likesCount = (data['likes_count'] as List?)?.isNotEmpty == true
            ? data['likes_count'][0]['count'] as int
            : 0;
        final int commentCount = (data['comment_count'] as List?)?.isNotEmpty == true
            ? data['comment_count'][0]['count'] as int
            : 0;

        // Create a mutable copy to inject counts directly for the Post.fromJson
        final Map<String, dynamic> postData = Map.from(data);
        postData['likes_count'] = likesCount;
        postData['comment_count'] = commentCount;

        return Post.fromJson(postData);
      }).toList();

      setState(() {
        _posts = fetchedPosts; // Update the internal posts list
        _isLoading = false;
      });
      print('✅ Posts fetched successfully. Count: ${_posts.length}');
    } catch (e) {
      print('❌ Error fetching posts: $e');
      setState(() {
        _errorMessage = 'Impossible de charger les posts. Veuillez vérifier votre connexion.';
        _isLoading = false;
      });
    }
  }
  // ---------------------------------------------------

  Future<void> _loadInitialLikes() async {
    try {
      final response = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id)
          .timeout(const Duration(seconds: 5));
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
    final isCurrentlyLiked = _likedPostIds.contains(post.id);

    // Optimistic UI update for better responsiveness
    setState(() {
      if (isCurrentlyLiked) {
        _likedPostIds.remove(post.id);
        post.likesCount--; // Decrement locally
      } else {
        _likedPostIds.add(post.id);
        post.likesCount++; // Increment locally
      }
    });

    _animationController.forward(from: 0);

    try {
      if (isCurrentlyLiked) {
        await _supabase
            .from('likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 5));
        print('Delete like for post ${post.id} by user $userId');
      } else {
        await _supabase.from('likes').insert({
          'post_id': post.id,
          'user_id': userId,
        }).timeout(const Duration(seconds: 5));
        print('Insert like for post ${post.id} by user $userId');
      }
      // After successful operation, you might want to refresh the specific post
      // or trigger a full fetch to ensure data consistency, especially if other
      // users can also like the same post.
      // For now, the optimistic update is combined with a full fetch on refresh.
      // await _fetchPosts(); // Uncomment if you want a full re-fetch after each like/unlike
    } catch (e) {
      print('Error toggling like for post ${post.id}: $e');
      String errorMessage = 'Erreur lors du like/désaimage. Veuillez réessayer.';
      if (e.toString().contains('violates row-level security policy')) {
        errorMessage = 'Erreur : Permissions insuffisantes pour aimer/supprimer le like.';
      } else if (e.toString().contains('foreign key constraint') || e.toString().contains('23503')) {
        errorMessage = 'Erreur : Publication ou utilisateur non trouvé.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Revert optimistic update if the operation failed
      setState(() {
        if (isCurrentlyLiked) {
          _likedPostIds.add(post.id);
          post.likesCount++;
        } else {
          _likedPostIds.remove(post.id);
          post.likesCount--;
        }
      });
    }
  }

  void _showCommentsPage(Post post) async {
    // Navigate to comments page and potentially get an updated comment count back
    final updatedCommentCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsPage(post: post, currentUser: widget.currentUser),
    );

    // If the comment count changed, update it locally
    if (updatedCommentCount != null && updatedCommentCount != post.commentCount) {
      setState(() {
        post.commentCount = updatedCommentCount;
      });
    }
  }

  void _showMediaViewer(BuildContext context, List<String> media, int initialIndex, bool isVideo) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MediaViewer(
          media: media,
          initialIndex: initialIndex,
          isVideo: isVideo,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _sharePost(Post post) {
    String shareText = post.caption ?? 'Check out this post from Bright Future Foundation!';
    if (post.imageUrls.isNotEmpty) {
      shareText += '\nImage: ${post.imageUrls.first}';
    } else if (post.videoUrls.isNotEmpty) {
      shareText += '\nVideo: ${post.videoUrls.first}';
    }
    Share.share(shareText, subject: 'Check out this post from Bright Future Foundation!');
  }

  Widget _buildPostItem(Post post, int index) {
    print('Construction du post ${post.id} avec caption: ${post.caption}');
    final isLiked = _likedPostIds.contains(post.id);
    final hasImages = post.imageUrls.isNotEmpty;
    final hasVideos = post.videoUrls.isNotEmpty;

    return FadeIn(
      delay: Duration(milliseconds: 100 * index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                // Fallback to a default asset image if profilePicture is null or empty
                backgroundImage: (post.profilePicture != null && post.profilePicture!.isNotEmpty)
                    ? NetworkImage(post.profilePicture!)
                    : const AssetImage('assets/default_profile.png') as ImageProvider<Object>?, // Make sure this asset exists
                onBackgroundImageError: (_, __) => const Icon(Icons.person, color: Colors.grey),
              ),
              title: Text(
                post.username,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
              subtitle: Text(
                timeago.format(post.timestamp, locale: 'fr'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            if (hasImages || hasVideos)
              Column(
                children: [
                  if (hasImages)
                    GestureDetector(
                      onTap: () => _showMediaViewer(context, post.imageUrls, 0, false),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: SizedBox(
                          height: 280,
                          child: PageView.builder(
                            itemCount: post.imageUrls.length,
                            itemBuilder: (context, index) => Image.network(
                              post.imageUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hasVideos)
                    GestureDetector(
                      onTap: () => _showMediaViewer(context, post.videoUrls, 0, true),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: SizedBox(
                          height: 400, // Adjusted for vertical video
                          child: ChewieVideoWidget(url: post.videoUrls[0], forceVertical: true),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                post.caption ?? '',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : Colors.grey.shade700,
                    label: post.likesCount.toString(),
                    onTap: () => _toggleLike(post),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    color: Colors.grey.shade700,
                    label: post.commentCount.toString(),
                    onTap: () => _showCommentsPage(post),
                  ),
                  const Spacer(),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    color: Colors.grey.shade700,
                    label: '',
                    onTap: () => _sharePost(post),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        _animationController.forward(from: 0);
        onTap();
      },
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.2).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the internally managed _posts list
    final sortedPosts = [..._posts]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPosts, // Retry fetching posts
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (sortedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aucun post à afficher',
              style: TextStyle(fontSize: 18, fontFamily: 'Roboto', color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPosts, // Trigger refresh using internal method
              child: const Text('Rafraîchir'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPosts, // Pull-to-refresh will call our internal fetch
      color: const Color(0xFF1E88E5),
      backgroundColor: Colors.white,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: sortedPosts.length,
        itemBuilder: (context, index) => _buildPostItem(sortedPosts[index], index),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Custom FadeIn widget for post animation (no change)
class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeIn({required this.child, this.delay = Duration.zero, Key? key}) : super(key: key);

  @override
  _FadeInState createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

// Full-screen media viewer (images or videos) (no change)
class MediaViewer extends StatefulWidget {
  final List<String> media;
  final int initialIndex;
  final bool isVideo;

  const MediaViewer({required this.media, this.initialIndex = 0, required this.isVideo, Key? key}) : super(key: key);

  @override
  _MediaViewerState createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.media.length,
            itemBuilder: (context, index) {
              return widget.isVideo
                  ? ChewieVideoWidget(url: widget.media[index], forceVertical: true)
                  : PhotoView(
                imageProvider: NetworkImage(widget.media[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
                loadingBuilder: (context, event) => Center(
                  child: CircularProgressIndicator(
                    value: event == null
                        ? null
                        : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  ),
                ),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (widget.media.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.media.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Roboto'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Video player widget with Chewie (improved initialization)
class ChewieVideoWidget extends StatefulWidget {
  final String url;
  final bool forceVertical;

  const ChewieVideoWidget({required this.url, this.forceVertical = false, Key? key}) : super(key: key);

  @override
  _ChewieVideoWidgetState createState() => _ChewieVideoWidgetState();
}

class _ChewieVideoWidgetState extends State<ChewieVideoWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController; // Made nullable for delayed initialization

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.url);
    _videoPlayerController.initialize().then((_) {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            aspectRatio: widget.forceVertical ? 9 / 16 : _videoPlayerController.value.aspectRatio, // Use video's aspect ratio if not forced vertical
            autoPlay: true,
            looping: true,
            showControls: true, // Typically, you want controls for a full-screen viewer
          );
        });
      }
    }).catchError((error) {
      print('Error initializing video: $error');
      // Handle video load error, e.g., show an error icon
      if (mounted) {
        setState(() {
          // You could set an error flag here to display a message
        });
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose(); // Dispose only if initialized
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _chewieController != null && _videoPlayerController.value.isInitialized
        ? Chewie(
      controller: _chewieController!,
    )
        : Container(
      color: Colors.black, // Dark background while loading video
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white), // White spinner on black background
      ),
    );
  }
}