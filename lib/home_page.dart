import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late SupabaseClient _supabase;
  late Set<String> _likedPostIds;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _likedPostIds = Set.from(widget.likedPostIds);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadInitialLikes();
  }

  Future<void> _loadInitialLikes() async {
    try {
      final response = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id)
          .timeout(const Duration(seconds: 5));
      if (kDebugMode) dev.log('Load initial likes response: $response');
      setState(() {
        _likedPostIds = response.map<String>((like) => like['post_id'] as String).toSet();
      });
    } catch (e) {
      if (kDebugMode) dev.log('Error loading initial likes: $e');
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
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 5));
        if (kDebugMode) dev.log('Delete like for post ${post.id} by user $userId');
        setState(() {
          _likedPostIds.remove(post.id);
        });
      } else {
        await _supabase.from('likes').insert({
          'post_id': post.id,
          'user_id': userId,
        }).timeout(const Duration(seconds: 5));
        if (kDebugMode) dev.log('Insert like for post ${post.id} by user $userId');
        setState(() {
          _likedPostIds.add(post.id);
        });
      }
      _animationController.forward(from: 0);
      await Future.delayed(const Duration(seconds: 1));
      try {
        await widget.refreshPosts();
        if (kDebugMode) dev.log('refreshPosts called successfully');
      } catch (e) {
        if (kDebugMode) dev.log('Error refreshing posts: $e');
      }
    } catch (e) {
      if (kDebugMode) dev.log('Error toggling like for post ${post.id}: $e');
      String errorMessage = 'Erreur lors du like/désaimage.';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsPage(post: post, currentUser: widget.currentUser),
    );
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
    if (kDebugMode) dev.log('Construction du post ${post.id} avec caption: ${post.caption}');
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
                backgroundImage: post.profilePicture != null ? NetworkImage(post.profilePicture!) : null,
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
                          height: 400, // Ajusté pour une vidéo verticale
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
    final sortedPosts = [...widget.posts]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
              onPressed: widget.refreshPosts,
              child: const Text('Rafraîchir'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.refreshPosts,
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

// Custom FadeIn widget for post animation
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

// Full-screen media viewer (images or videos)
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

// Video player widget with Chewie
class ChewieVideoWidget extends StatefulWidget {
  final String url;
  final bool forceVertical;

  const ChewieVideoWidget({required this.url, this.forceVertical = false, Key? key}) : super(key: key);

  @override
  _ChewieVideoWidgetState createState() => _ChewieVideoWidgetState();
}

class _ChewieVideoWidgetState extends State<ChewieVideoWidget> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.network(widget.url);
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: widget.forceVertical ? 9 / 16 : null,
      autoPlay: true,
      looping: true,
      showControls: false,
    );
    _videoPlayerController.initialize().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayerController.value.isInitialized
        ? Chewie(
      controller: _chewieController,
    )
        : const Center(child: CircularProgressIndicator());
  }
}