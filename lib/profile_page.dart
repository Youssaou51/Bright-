import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user.dart' as localUser;
import 'manage_roles_page.dart';

class ProfilePage extends StatefulWidget {
  final localUser.User? currentUser;
  final Future<void> Function()? refreshPosts;

  const ProfilePage({Key? key, this.currentUser, this.refreshPosts}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late String _username;
  late String _pseudo;
  late String? _profilePictureUrl;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _username = widget.currentUser?.username ?? 'Utilisateur';
    _pseudo = widget.currentUser?.pseudo ?? '';
    _profilePictureUrl = widget.currentUser?.imageUrl;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _checkUserRoleAndNavigateCheckOnly().then((_) {
      setState(() {
        _isLoading = false;
      });
    });
    _loadProfile();
  }

  Future<void> _checkUserRoleAndNavigateCheckOnly() async {
    final user = _supabase.auth.currentUser;
    print('Dashboard - Checking role for user: ${user?.id}');

    if (user == null) {
      print('Dashboard - No authenticated user');
      setState(() => _isAdmin = false);
      return;
    }

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      final role = (response['role'] as String?)?.toLowerCase() ?? 'user';
      print('Dashboard - Role retrieved: $role for user id: ${user.id}');
      setState(() {
        _isAdmin = role == 'admin';
      });
    } catch (e) {
      print('Dashboard - Error checking user role: $e, Stack trace: ${StackTrace.current}');
      setState(() => _isAdmin = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      print('Dashboard - Loading profile for user id: ${widget.currentUser?.id}');
      final response = await _supabase
          .from('users')
          .select('username, pseudo, profile_picture')
          .eq('id', widget.currentUser!.id)
          .single();
      setState(() {
        _username = response['username'] as String? ?? _username;
        _pseudo = response['pseudo'] as String? ?? _pseudo;
        _profilePictureUrl = response['profile_picture'] as String?;
      });
    } catch (e) {
      print('Dashboard - Error loading profile: $e, StackTrace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement du profil : $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _changeProfilePicture() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF1976D2)),
                title: Text('Choisir dans la galerie', style: GoogleFonts.poppins()),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    await _uploadProfilePicture(File(pickedFile.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
                title: Text('Prendre une photo', style: GoogleFonts.poppins()),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    await _uploadProfilePicture(File(pickedFile.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadProfilePicture(File file) async {
    if (widget.currentUser == null || widget.currentUser!.username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur : Nom d\'utilisateur non trouvé'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final username = widget.currentUser!.username.replaceAll('@', '_').replaceAll('.', '_');
    final fileName = '${username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      if (_profilePictureUrl != null && _isValidUrl(_profilePictureUrl!)) {
        final oldFileName = _profilePictureUrl!.split('/').last;
        await _supabase.storage.from('profiles').remove([oldFileName]).catchError((e) => print('Dashboard - Error removing old image: $e'));
      }

      await _supabase.storage.from('profiles').upload(fileName, file);
      final imageUrl = _supabase.storage.from('profiles').getPublicUrl(fileName);

      final userResponse = await _supabase
          .from('users')
          .update({'profile_picture': imageUrl})
          .eq('id', widget.currentUser!.id)
          .select()
          .single();

      await _supabase
          .from('posts')
          .update({'profile_picture': imageUrl})
          .eq('user_id', widget.currentUser!.id);

      if (widget.refreshPosts != null) {
        await widget.refreshPosts!();
      }

      setState(() {
        _profilePictureUrl = userResponse['profile_picture'] as String?;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour !')),
      );
    } catch (e) {
      print('Dashboard - Error uploading profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour de la photo : $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _changeUsername() async {
    final TextEditingController usernameController = TextEditingController(text: _username);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            Text('Changer le nom d’utilisateur', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                hintText: 'Nouveau nom d’utilisateur',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newUsername = usernameController.text.trim();
                if (newUsername.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom d’utilisateur ne peut pas être vide')),
                  );
                  return;
                }
                try {
                  await _supabase.from('users').update({
                    'username': newUsername,
                  }).eq('id', widget.currentUser!.id);
                  setState(() => _username = newUsername);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nom d’utilisateur mis à jour !')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1976D2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Enregistrer', style: GoogleFonts.poppins(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePseudo() async {
    final TextEditingController pseudoController = TextEditingController(text: _pseudo);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            Text('Changer le pseudo', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: pseudoController,
              decoration: InputDecoration(
                hintText: 'Nouveau pseudo',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newPseudo = pseudoController.text.trim();
                try {
                  await _supabase.from('users').update({
                    'pseudo': newPseudo.isEmpty ? null : newPseudo,
                  }).eq('id', widget.currentUser!.id);
                  setState(() => _pseudo = newPseudo);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pseudo mis à jour !')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1976D2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Enregistrer', style: GoogleFonts.poppins(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false); // Changed to '/welcome'
      }
    } catch (e) {
      print('Dashboard - Sign-out error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de déconnexion : $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file:///') || url.contains('via.placeholder.com')) return false;
    return Uri.tryParse(url)?.hasAuthority ?? false;
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _animation,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(icon, color: Color(0xFF1976D2), size: 28),
            title: Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Dashboard - Building ProfilePage - isAdmin: $_isAdmin, isLoading: $_isLoading');
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: null,
            automaticallyImplyLeading: false,
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 2,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _changeProfilePicture,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _isValidUrl(_profilePictureUrl)
                                ? NetworkImage(_profilePictureUrl!)
                                : const AssetImage('assets/default_profile.png') as ImageProvider,
                            onBackgroundImageError: _isValidUrl(_profilePictureUrl)
                                ? (exception, stackTrace) {
                              print('Dashboard - Error loading profile picture: $exception');
                            }
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
                          ),
                          child: const Icon(Icons.camera_alt, size: 24, color: Color(0xFF1976D2)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 2,
                    width: 80,
                    color: Color(0xFF1976D2).withOpacity(0.3),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: Icon(Icons.settings, color: Color(0xFF1976D2), size: 30),
                  onPressed: () {
                    print('Dashboard - Navigating to ManageRolesPage');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageRolesPage(supabase: _supabase),
                      ),
                    );
                  },
                  tooltip: 'Gérer les rôles',
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _username,
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pseudo.isEmpty ? 'Ajouter un pseudo' : '@$_pseudo',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Paramètres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingOption(
                    icon: Icons.person,
                    title: 'Changer le nom d’utilisateur',
                    onTap: _changeUsername,
                  ),
                  _buildSettingOption(
                    icon: Icons.alternate_email,
                    title: 'Changer le pseudo',
                    onTap: _changePseudo,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout, size: 24),
                    label: Text(
                      'Déconnexion',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}