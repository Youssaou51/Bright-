import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reports_page.dart';
import 'home_page.dart';
import 'dart:io';
import 'profile_page.dart';
import 'tasks_page.dart';
import 'post.dart';
import 'user.dart' as local;

class DashboardPage extends StatefulWidget {
  final local.User currentUser;

  const DashboardPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late PageController _pageController;
  final ImagePicker _picker = ImagePicker();
  List<Post> _posts = [];
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadPosts(); // Ajoutez cette ligne
  }

  Future<void> _loadPosts() async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*') // Get all columns
          .order('timestamp', ascending: false); // Newest first

      if (mounted) {
        setState(() {
          _posts = response.map<Post>((post) => Post.fromJson(post)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showMediaSourceDialog();
    } else {
      _pageController.jumpToPage(index);
      _animationController.forward().then((value) {
        _animationController.reverse();
      });
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo options
              ListTile(
                leading: Icon(Icons.camera, color: Colors.blue),
                title: Text('Take a Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    _promptForCaption([File(pickedFile.path)], [], "New Photo Post");
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: Colors.blue),
                title: Text('Choose Photo from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    _promptForCaption([File(pickedFile.path)], [], "New Photo Post");
                  }
                },
              ),
              Divider(),
              // Video options
              ListTile(
                leading: Icon(Icons.videocam, color: Colors.red),
                title: Text('Record a Video'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
                  if (pickedFile != null) {
                    _promptForCaption([], [File(pickedFile.path)], "New Video Post");
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library, color: Colors.red),
                title: Text('Choose Video from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    _promptForCaption([], [File(pickedFile.path)], "New Video Post");
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _promptForCaption(List<File> images, List<File> videos, String defaultCaption) {
    String caption = defaultCaption;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Caption'),
          content: Container(
            width: double.maxFinite,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (images.isNotEmpty)
                  Image.file(images[0], fit: BoxFit.cover, width: double.maxFinite),
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: TextField(
                    onChanged: (value) {
                      caption = value;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter caption...',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addPost(images, videos, caption);
              },
              child: Text('Submit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPost(List<File> images, List<File> videos, String caption) async {
    try {
      final postId = DateTime.now().millisecondsSinceEpoch.toString();
      List<String> imageUrls = [];
      List<String> videoUrls = [];

      // Upload images
      if (images.isNotEmpty) {
        for (var image in images) {
          final imagePath = 'posts/images/$postId-${image.path.split('/').last}';
          await _supabase.storage.from('posts').upload(imagePath, image);
          final imageUrl = _supabase.storage.from('posts').getPublicUrl(imagePath);
          imageUrls.add(imageUrl);
        }
      }

      // Upload videos
      if (videos.isNotEmpty) {
        for (var video in videos) {
          final videoPath = 'posts/videos/$postId-${video.path.split('/').last}';
          await _supabase.storage.from('posts').upload(videoPath, video);
          final videoUrl = _supabase.storage.from('posts').getPublicUrl(videoPath);
          videoUrls.add(videoUrl);
        }
      }

      // Construct the profile picture URL based on the username
      final profilePictureUrl = _supabase.storage.from('profiles').getPublicUrl('${widget.currentUser.username}_profile.jpg');

      // Insert into database
      await _supabase.from('posts').insert({
        'id': postId,
        'user_id': widget.currentUser.id,
        'username': widget.currentUser.username,
        'profile_picture': profilePictureUrl, // Use constructed profile picture URL
        'caption': caption,
        'likes_count': 0,
        'image_urls': imageUrls.isNotEmpty ? imageUrls : null,
        'video_urls': videoUrls.isNotEmpty ? videoUrls : null,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update UI
      if (mounted) {
        setState(() {
          _posts.insert(0, Post(
            id: postId,
            userId: widget.currentUser.id,
            username: widget.currentUser.username,
            profilePicture: profilePictureUrl, // Use constructed profile picture URL
            caption: caption,
            images: imageUrls,
            videos: videoUrls,
            likedBy: [],
            likesCount: 0,
            comments: [],
            timestamp: DateTime.now(),
          ));
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      debugPrint('Error creating post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Bar
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bright Future Foundation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.black54),
                  onPressed: () {
                    // Handle notifications
                  },
                ),
              ],
            ),
          ),
          // PageView for the content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                HomePage(posts: _posts, currentUser: widget.currentUser,refreshPosts: _loadPosts ),
                ReportsPage(),
                Container(), // Placeholder for the media icon action
                TasksPage(),
                ProfilePage(currentUser: widget.currentUser),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.fileAlt), label: 'Reports'),
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.image), label: 'Media'),
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.tasks), label: 'Tasks'),
          BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.user), label: 'Profile'),
        ],
      ),
    );
  }
}