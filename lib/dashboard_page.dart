import 'dart:io';
import 'package:flutter/material.dart';
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
import 'utils/error_handler.dart';
import 'dart:async';
import 'dart:io';


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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    print('DashboardPage init: user=${widget.currentUser.id}, username=${widget.currentUser.username}');
    print('Supabase auth user: ${Supabase.instance.client.auth.currentUser?.id}');
    _checkUserRole();
    _loadPosts();
    _loadInitialAmount();
  }

  Future<void> _checkUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isAdmin = false);
      return;
    }

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 6));

      final role = response['role'] as String? ?? 'user';
      print('✅ Rôle utilisateur : $role');

      setState(() => _isAdmin = role.toLowerCase() == 'admin');
    } on SocketException {
      print('⚠️ Aucune connexion Internet.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pas de connexion Internet.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on TimeoutException {
      print('⏳ Timeout lors de la vérification du rôle utilisateur.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Le serveur met trop de temps à répondre.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification du rôle utilisateur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue. Rôle par défaut : utilisateur.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _isAdmin = false);
    }
  }

  Future<void> _loadInitialAmount() async {
    try {
      final response = await _supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single()
          .timeout(const Duration(seconds: 6));

      final amount = (response['amount'] as num?)?.toDouble() ?? 0.0;
      print('💰 Montant initial chargé : $amount');

      if (mounted) {
        setState(() => _currentAmount = amount);
      }
    } on SocketException {
      print('⚠️ Pas de connexion Internet.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger le montant (hors ligne).',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _currentAmount = 0.0);
      }
    } on TimeoutException {
      print('⏳ Timeout lors du chargement du montant.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Temps de réponse dépassé. Réessayez plus tard.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        setState(() => _currentAmount = 0.0);
      }
    } catch (e) {
      print('Erreur inattendue : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du montant.',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _currentAmount = 0.0);
      }
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
          content: Text(errorMessage, style: GoogleFonts.poppins()),
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
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
                  fillColor: Colors.grey[50],
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
                      backgroundColor: Color(0xFF1976D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      "Publier",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500, // Corrected from Weight.w500
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
      final hasConnection = await ErrorHandler.checkInternetConnection();
      if (!hasConnection) {
        ErrorHandler.showError(context, "Aucune connexion Internet. Réessaie plus tard.");
        return;
      }

      final postId = const Uuid().v4();
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

      final inserted = await _supabase.from('posts').insert(post).select().single();

      // 🔔 Notification via Edge Function
      await _supabase.functions.invoke(
        'sendNotification',
        body: {
          'table': 'posts',
          'record': {
            'id': inserted['id'],
            'title': caption,
            'user_id': widget.currentUser.id,
            'user_name': widget.currentUser.username,
          },
        },
      );

      // Forcez l'actualisation des posts
      await _loadPosts();

      // Montrez un message de succès
      ErrorHandler.showSuccess(context, "Post publié avec succès !");

      // Naviguez vers la page d'accueil pour voir le nouveau post
      _pageController.jumpToPage(0);
      setState(() {
        _selectedIndex = 0;
      });

    } catch (error) {
      ErrorHandler.handleException(context, error);
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
                  fillColor: Colors.grey[50],
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
                      if (enteredAmount == null || enteredAmount < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Veuillez entrer un montant valide',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        return;
                      }

                      print('Updating funds to $enteredAmount');

                      try {
                        await _supabase

                            .from('funds')
                            .upsert({
                          'id': 'foundation-funds',
                          'amount': enteredAmount,
                          'updated_by': widget.currentUser.username,
                          'updated_at': DateTime.now().toIso8601String(),
                        })
                            .timeout(const Duration(seconds: 6));

                        setState(() {
                          _currentAmount = enteredAmount;
                        });

                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Montant mis à jour avec succès !',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.teal[700]!,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      } on TimeoutException {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '⏳ La connexion a expiré. Vérifiez votre réseau.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.orangeAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      } on SocketException {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '⚠️ Pas de connexion Internet. Réessayez plus tard.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      } catch (error) {
                        print('Unexpected error updating funds: $error');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '❌ Erreur inattendue. Veuillez réessayer.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bright Future Foundation',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (_isAdmin)
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.black, size: 28),
                      onPressed: _showUpdateFundsDialog,
                      tooltip: 'Modifier le montant des fonds',
                    ),
                ],
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
                    color: Colors.black.withOpacity(0.05),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Color(0xFF1976D2),
          unselectedItemColor: Colors.black,
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
                child: Icon(Icons.home),
              ),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 1 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(Icons.bar_chart),
              ),
              label: "Reports",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 2 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(Icons.camera_alt),
              ),
              label: "Media",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 3 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(Icons.task),
              ),
              label: "Tasks",
            ),
            BottomNavigationBarItem(
              icon: AnimatedScale(
                scale: _selectedIndex == 4 ? 1.2 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(Icons.person),
              ),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}