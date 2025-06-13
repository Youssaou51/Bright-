import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'reports_page.dart';
import 'tasks_page.dart';
import 'post.dart';
import 'user.dart' as local;

class DashboardPage extends StatefulWidget {
  final local.User currentUser;

  const DashboardPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Post> _posts = [];
  String _foundationAmount = "Chargement...";
  Set<String> _likedPostIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadPosts();
    _loadFoundationFunds();

  }

  Future<void> _loadPosts() async {
    try {
      final postsResponse = await _supabase
          .from('posts')
          .select('*')
          .order('timestamp', ascending: false);

      final likesResponse = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id);

      final likedPostIds = likesResponse
          .map<String>((like) => like['post_id'] as String)
          .toSet();

      setState(() {
        _posts = postsResponse.map<Post>((e) => Post.fromJson(e)).toList();
        _likedPostIds = likedPostIds; // Ajoute ça comme variable dans le state
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des posts : $e')),
      );
    }
  }


  Future<void> _loadFoundationFunds() async {
    try {
      final response = await _supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single();
      setState(() {
        _foundationAmount = response['amount'].toString() + " €";
      });
    } catch (e) {
      setState(() {
        _foundationAmount = "Erreur";
      });
    }
  }

  Future<void> _editFoundationFunds() async {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Modifier les fonds"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Nouveau montant (€)"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null) {
                await _supabase.from('funds').upsert({
                  'id': 'foundation-funds',
                  'amount': amount,
                  'updated_by': widget.currentUser.username,
                  'updated_at': DateTime.now().toIso8601String()
                });
                Navigator.pop(context);
                _loadFoundationFunds();
              }
            },
            child: Text("Enregistrer"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler"),
          )
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _showMediaSourceDialog();
    } else {
      _pageController.jumpToPage(index);
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(source: ImageSource.camera);
                if (file != null) {
                  _promptForCaption([File(file.path)], [], 'Nouveau post photo');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.image, color: Colors.green),
              title: Text('Galerie photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(source: ImageSource.gallery);
                if (file != null) {
                  _promptForCaption([File(file.path)], [], 'Nouveau post photo');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: Colors.red),
              title: Text('Enregistrer une vidéo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickVideo(source: ImageSource.camera);
                if (file != null) {
                  _promptForCaption([], [File(file.path)], 'Nouveau post vidéo');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library, color: Colors.deepPurple),
              title: Text('Vidéo depuis galerie'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickVideo(source: ImageSource.gallery);
                if (file != null) {
                  _promptForCaption([], [File(file.path)], 'Nouveau post vidéo');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _promptForCaption(List<File> images, List<File> videos, String defaultCaption) {
    String caption = defaultCaption;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Ajouter une légende"),
          content: TextField(
            onChanged: (value) => caption = value,
            decoration: InputDecoration(
              hintText: 'Saisir une légende...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addPost(images, videos, caption);
              },
              child: Text("Publier"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Annuler"),
            )
          ],
        );
      },
    );
  }

  Future<void> _addPost(List<File> images, List<File> videos, String caption) async {
    try {
      final postId = Uuid().v4();
      List<String> imageUrls = [];
      List<String> videoUrls = [];

      for (var image in images) {
        final path = 'posts/images/$postId-${image.path.split('/').last}';
        await _supabase.storage.from('posts').upload(path, image);
        imageUrls.add(_supabase.storage.from('posts').getPublicUrl(path));
      }

      for (var video in videos) {
        final path = 'posts/videos/$postId-${video.path.split('/').last}';
        await _supabase.storage.from('posts').upload(path, video);
        videoUrls.add(_supabase.storage.from('posts').getPublicUrl(path));
      }

      final profilePictureUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl('${widget.currentUser.username}_profile.jpg');

      final post = {
        'id': postId,
        'user_id': widget.currentUser.id,
        'username': widget.currentUser.username,
        'profile_picture': profilePictureUrl,
        'caption': caption,
        'likes_count': 0,
        'image_urls': imageUrls,
        'video_urls': videoUrls,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _supabase.from('posts').insert(post);
      _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Post publié !")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F8FA),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bright Future Foundation',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Icon(Icons.notifications_none, color: Colors.white)
                  ],
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.currentUser.role == 'admin' ? _editFoundationFunds : null,
                  child: SizedBox(
                    height: 24,
                    child: Marquee(
                      text: '💰 Fonds disponibles : $_foundationAmount',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      blankSpace: 20.0,
                      velocity: 50.0,
                      pauseAfterRound: Duration(seconds: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                HomePage(posts: _posts, currentUser: widget.currentUser,likedPostIds: _likedPostIds, refreshPosts: _loadPosts),
                ReportsPage(),
                Container(),
                TasksPage(),
                ProfilePage(currentUser: widget.currentUser),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey.shade600,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.home), label: "Home"),
            BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.fileAlt), label: "Reports"),
            BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.plusSquare), label: "Media"),
            BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.tasks), label: "Tasks"),
            BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.user), label: "Profile"),
          ],
        ),
      ),
    );
  }
}
