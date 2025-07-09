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
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  late Set<String> _likedPostIds;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _likedPostIds = Set.from(widget.likedPostIds);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _checkIfAdmin();
    _fetchPosts();
    _loadInitialLikes();
  }

  Future<void> _checkIfAdmin() async {
    final userId = widget.currentUser.id;
    final response = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    if (response != null && response['role'] == 'admin') {
      setState(() {
        // Update currentUser.role if mutable, or manage admin state separately
      });
    }
  }

  Future<void> _fetchPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('posts')
          .select('''
            *,
            likes_count:likes(count),
            comment_count:comments(count)
          ''')
          .order('timestamp', ascending: false)
          .limit(50);
      final List<Post> fetchedPosts = response.map((data) {
        final int likesCount = (data['likes_count'] as List?)?.isNotEmpty == true
            ? data['likes_count'][0]['count'] as int
            : 0;
        final int commentCount = (data['comment_count'] as List?)?.isNotEmpty == true
            ? data['comment_count'][0]['count'] as int
            : 0;
        final Map<String, dynamic> postData = Map.from(data);
        postData['likes_count'] = likesCount;
        postData['comment_count'] = commentCount;
        return Post.fromJson(postData);
      }).toList();
      if (mounted) {
        setState(() {
          _posts = fetchedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de charger les posts. Veuillez vérifier votre connexion.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialLikes() async {
    try {
      final response = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id)
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _likedPostIds = response.map<String>((like) => like['post_id'] as String).toSet();
        });
      }
    } catch (e) {
      print('Error loading initial likes: $e');
    }
  }

  Future<void> _toggleLike(Post post) async {
    final userId = widget.currentUser.id;
    final isCurrentlyLiked = _likedPostIds.contains(post.id);
    setState(() {
      if (isCurrentlyLiked) {
        _likedPostIds.remove(post.id);
        post.likesCount--;
      } else {
        _likedPostIds.add(post.id);
        post.likesCount++;
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
      } else {
        await _supabase.from('likes').insert({
          'post_id': post.id,
          'user_id': userId,
        }).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
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
    final updatedCommentCount = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(post: post, currentUser: widget.currentUser),
        fullscreenDialog: true,
      ),
    );
    if (updatedCommentCount != null && updatedCommentCount != post.commentCount) {
      setState(() {
        post.commentCount = updatedCommentCount;
      });
    }
  }

  void _showMediaViewer(BuildContext context, List<String> media, int initialIndex, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewer(
          media: media,
          initialIndex: initialIndex,
          isVideo: isVideo,
        ),
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

  Future<void> _deletePost(Post post) async {
    try {
      await _supabase
          .from('posts')
          .delete()
          .eq('id', post.id);
      await widget.refreshPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post supprimé avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression du post: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showDeleteDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le post'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce post ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost(post);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Post post, int index) {
    final isLiked = _likedPostIds.contains(post.id);
    final hasImages = post.imageUrls.isNotEmpty;
    final hasVideos = post.videoUrls.isNotEmpty;
    final isOwner = post.userId == widget.currentUser.id;
    final isAdmin = widget.currentUser.role == 'admin';

    return AnimatedOpacity(
      duration: Duration(milliseconds: 300 + (100 * index % 300)),
      opacity: 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (post.profilePicture != null && post.profilePicture!.isNotEmpty)
                          ? NetworkImage(post.profilePicture!)
                          : const AssetImage('assets/default_profile.png') as ImageProvider<Object>?,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeago.format(post.timestamp, locale: 'fr'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                      onSelected: (value) {
                        if (value == 'delete' && (isOwner || isAdmin)) {
                          _showDeleteDialog(post);
                        }
                      },
                      itemBuilder: (context) => [
                        if (isOwner || isAdmin)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (post.caption?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    post.caption!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              if (hasImages || hasVideos) ...[
                if (hasImages)
                  GestureDetector(
                    onTap: () => _showMediaViewer(context, post.imageUrls, 0, false),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PageView.builder(
                          itemCount: post.imageUrls.length,
                          itemBuilder: (context, index) => Image.network(
                            post.imageUrls[index],
                            fit: BoxFit.cover,
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                              ),
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
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ChewieVideoWidget(url: post.videoUrls[0]),
                      ),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    _buildLikeButton(post, isLiked),
                    const SizedBox(width: 16),
                    _buildCommentButton(post),
                    const Spacer(),
                    _buildShareButton(post),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikeButton(Post post, bool isLiked) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _toggleLike(post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey<bool>(isLiked),
                color: isLiked ? Colors.redAccent : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              post.likesCount.toString(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentButton(Post post) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showCommentsPage(post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.mode_comment_outlined,
              color: Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 4),
            Text(
              post.commentCount.toString(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(Post post) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _sharePost(post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(
          Icons.share_outlined,
          color: Colors.grey.shade700,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedPosts = [..._posts]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1976D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucun post à afficher',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1976D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Rafraîchir'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchPosts,
      color: Color(0xFF1976D2),
      backgroundColor: Colors.white,
      displacement: 40,
      edgeOffset: 20,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPostItem(sortedPosts[index], index),
                childCount: sortedPosts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class MediaViewer extends StatefulWidget {
  final List<String> media;
  final int initialIndex;
  final bool isVideo;

  const MediaViewer({
    required this.media,
    this.initialIndex = 0,
    required this.isVideo,
    Key? key,
  }) : super(key: key);

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
                  ? ChewieVideoWidget(url: widget.media[index])
                  : PhotoView(
                imageProvider: NetworkImage(widget.media[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: widget.media[index]),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (widget.media.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.media.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChewieVideoWidget extends StatefulWidget {
  final String url;
  final bool? forceVertical;

  const ChewieVideoWidget({
    required this.url,
    this.forceVertical,
    Key? key,
  }) : super(key: key);

  @override
  _ChewieVideoWidgetState createState() => _ChewieVideoWidgetState();
}

class _ChewieVideoWidgetState extends State<ChewieVideoWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoPlayerController = VideoPlayerController.network(widget.url);
    try {
      await _videoPlayerController.initialize();
      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            aspectRatio: widget.forceVertical ?? false
                ? 9 / 16
                : _videoPlayerController.value.aspectRatio,
            autoPlay: false,
            looping: false,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: Color(0xFF1976D2),
              handleColor: Color(0xFF1976D2),
              bufferedColor: Colors.grey.shade300,
              backgroundColor: Colors.grey.shade500,
            ),
            placeholder: Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 50),
              ),
            ),
            errorBuilder: (context, errorMessage) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading video',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _togglePlay() {
    if (_chewieController != null) {
      if (_isPlaying) {
        _chewieController!.pause();
      } else {
        _chewieController!.play();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController != null && _videoPlayerController.value.isInitialized) {
      return GestureDetector(
        onTap: _togglePlay,
        child: Chewie(
          controller: _chewieController!,
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
  }
}