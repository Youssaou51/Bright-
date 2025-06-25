import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'reports_page.dart';
import 'tasks_page.dart';
import 'post.dart';
import 'user.dart' as local;
import 'foundation_amount_widget.dart';

class DashboardPage extends StatefulWidget {
  final local.User currentUser;

  const DashboardPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Post> _posts = [];
  Set<String> _likedPostIds = {};
  double _currentAmount = 0.0;
  bool _isAdmin = false; // Track if the user is an admin

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    print('DashboardPage init: user=${widget.currentUser.id}, username=${widget.currentUser.username}');
    print('Supabase auth user: ${Supabase.instance.client.auth.currentUser?.id}');
    _checkUserRole(); // Check user role on init
    _loadPosts();
    _loadInitialAmount(); // Load initial amount
  }

  Future<void> _checkUserRole() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isAdmin = false;
      });
      return;
    }

    try {
      final userRoleResponse = await _supabase
          .from('users') // ✅ Pas besoin de 'public.'
          .select('role')
          .eq('id', user.id)
          .single();

      final userRole = userRoleResponse['role'] as String? ?? 'user';

      print('Rôle récupéré depuis la table users : $userRole');

      setState(() {
        _isAdmin = userRole.toLowerCase() == 'admin';
      });
    } catch (e) {
      print('Erreur lors de la vérification du rôle utilisateur : $e');
      setState(() {
        _isAdmin = false; // On considère par défaut que l'utilisateur n'est pas admin
      });
    }
  }


  Future<void> _loadInitialAmount() async {
    try {
      final response = await _supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single()
          .catchError((e) => print('Error loading initial amount: $e'));
      setState(() {
        _currentAmount = (response['amount'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      print('Error loading initial amount: $e');
      setState(() {
        _currentAmount = 0.0;
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      print('Début du chargement des posts');
      final postsResponse = await _supabase
          .from('posts')
          .select('''
          id, user_id, username, profile_picture, caption, image_urls, video_urls, likes_count, timestamp,
          comment_count:comments(count)
        ''')
          .order('timestamp', ascending: false)
          .timeout(const Duration(seconds: 5));

      print('Posts response: $postsResponse');

      final likesResponse = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', widget.currentUser.id)
          .timeout(const Duration(seconds: 5));

      print('Likes response: $likesResponse');

      final likedPostIds = likesResponse
          .map<String>((like) => like['post_id'] as String)
          .toSet();

      setState(() {
        _posts = postsResponse.map<Post>((e) {
          final postJson = Map<String, dynamic>.from(e);
          final commentCountList = e['comment_count'] as List<dynamic>?;
          postJson['comment_count'] = commentCountList != null && commentCountList.isNotEmpty
              ? (commentCountList[0] as Map<String, dynamic>)['count'] as int
              : 0;
          return Post.fromJson(postJson);
        }).toList();
        _likedPostIds = likedPostIds;
        print('Nombre de posts chargés : ${_posts.length}');
      });
    } catch (e, stackTrace) {
      print('Erreur lors du chargement des posts : $e');
      print('Stack trace: $stackTrace');
      String errorMessage = 'Erreur de chargement des posts';
      if (e is SocketException) {
        errorMessage = 'Problème de connexion réseau. Vérifiez votre internet.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Délai de connexion dépassé. Serveur indisponible.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blueAccent),
              title: Text('Prendre une photo', style: GoogleFonts.poppins()),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(source: ImageSource.camera);
                if (file != null) {
                  _promptForCaption([File(file.path)], [], 'Nouveau post photo');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.image, color: Colors.teal),
              title: Text('Galerie photo', style: GoogleFonts.poppins()),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(source: ImageSource.gallery);
                if (file != null) {
                  _promptForCaption([File(file.path)], [], 'Nouveau post photo');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: Colors.redAccent),
              title: Text('Enregistrer une vidéo', style: GoogleFonts.poppins()),
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
              title: Text('Vidéo depuis galerie', style: GoogleFonts.poppins()),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Ajouter une légende",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                onChanged: (value) => caption = value,
                decoration: InputDecoration(
                  hintText: 'Saisir une légende...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: GoogleFonts.poppins(),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Annuler",
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _addPost(images, videos, caption);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      "Publier",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

      final userResponse = await _supabase
          .from('users')
          .select('profile_picture')
          .eq('id', widget.currentUser.id)
          .single();
      final profilePictureUrl = userResponse['profile_picture'] as String?;

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
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post publié !', style: GoogleFonts.poppins()),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showUpdateFundsDialog() {
    final _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Modifier le montant de la fondation',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Nouveau montant (€)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: GoogleFonts.poppins(),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      print('Update funds dialog cancelled');
                      Navigator.pop(dialogContext);
                    },
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final enteredAmount = double.tryParse(_controller.text);
                      if (enteredAmount != null && enteredAmount >= 0) {
                        print('Updating funds to $enteredAmount');
                        try {
                          final response = await _supabase.from('funds').upsert({
                            'id': 'foundation-funds',
                            'amount': enteredAmount,
                            'updated_by': widget.currentUser.username,
                            'updated_at': DateTime.now().toIso8601String(),
                          });
                          print('Update funds response: $response');
                          setState(() {
                            _currentAmount = enteredAmount;
                          });
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Montant mis à jour avec succès !',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: Colors.teal,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        } catch (error) {
                          print('Error updating funds: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur mise à jour : $error',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } else {
                        print('Invalid amount entered');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Veuillez entrer un montant valide',
                                style: GoogleFonts.poppins()),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Mettre à jour',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).catchError((error) {
      print('Error showing update funds dialog: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Bright Future Foundation',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (_isAdmin) // Show edit icon only if user is admin
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.white, size: 28),
                            onPressed: _showUpdateFundsDialog,
                            tooltip: 'Modifier le montant des fonds',
                            constraints: BoxConstraints(minWidth: 48, minHeight: 48),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: FoundationAmountWidget(
                    supabase: _supabase,
                    initialAmount: _currentAmount,
                    onAmountUpdated: (amount) {
                      print('Amount updated: $amount');
                      setState(() {
                        _currentAmount = amount;
                      });
                    },
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      HomePage(
                        posts: _posts,
                        currentUser: widget.currentUser,
                        likedPostIds: _likedPostIds,
                        refreshPosts: _loadPosts,
                      ),
                      ReportsPage(),
                      Container(), // Placeholder for Media page
                      TasksPage(),
                      ProfilePage(
                        currentUser: widget.currentUser,
                        refreshPosts: _loadPosts,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey[500],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 0 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: FaIcon(FontAwesomeIcons.home),
              ),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 1 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: FaIcon(FontAwesomeIcons.fileAlt),
              ),
              label: "Reports",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 2 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: FaIcon(FontAwesomeIcons.plusSquare),
              ),
              label: "Media",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 3 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: FaIcon(FontAwesomeIcons.tasks),
              ),
              label: "Tasks",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 4 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: FaIcon(FontAwesomeIcons.user),
              ),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}