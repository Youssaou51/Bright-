import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user.dart' as localUser;
import 'manage_roles_page.dart';

class ProfilePage extends StatefulWidget {
  final localUser.User? currentUser;
  final Future<void> Function()? refreshPosts;

  const ProfilePage({Key? key, this.currentUser, this.refreshPosts})
      : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  late String _username;
  late String _pseudo;
  late String? _profilePictureUrl;
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
      setState(() => _isLoading = false);
    });
    _loadProfile();
  }

  Future<void> _checkUserRoleAndNavigateCheckOnly() async {
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
          .timeout(const Duration(seconds: 7));

      final role = (response['role'] as String?)?.toLowerCase() ?? 'user';
      setState(() => _isAdmin = role == 'admin');
    } on TimeoutException {
      _showError("⏰ Délai dépassé lors de la vérification du rôle.");
    } on SocketException {
      _showError("📡 Pas de connexion Internet.");
    } catch (e) {
      _showError("Erreur lors de la vérification du rôle : $e");
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _supabase
          .from('users')
          .select('username, pseudo, profile_picture')
          .eq('id', widget.currentUser!.id)
          .single()
          .timeout(const Duration(seconds: 7));

      setState(() {
        _username = response['username'] as String? ?? _username;
        _pseudo = response['pseudo'] as String? ?? _pseudo;
        _profilePictureUrl = response['profile_picture'] as String?;
      });
    } on TimeoutException {
      _showError("⏰ Délai dépassé lors du chargement du profil.");
    } on SocketException {
      _showError("📡 Pas de connexion Internet.");
    } catch (e) {
      _showError("Erreur de chargement du profil : $e");
    }
  }

  Future<void> _changeProfilePicture() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF1976D2)),
            title:
            Text('Choisir dans la galerie', style: GoogleFonts.poppins()),
            onTap: () async {
              Navigator.pop(context);
              final pickedFile =
              await _picker.pickImage(source: ImageSource.gallery);
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
              final pickedFile =
              await _picker.pickImage(source: ImageSource.camera);
              if (pickedFile != null) {
                await _uploadProfilePicture(File(pickedFile.path));
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _uploadProfilePicture(File file) async {
    if (widget.currentUser == null) {
      _showShortError("Utilisateur non connecté");
      return;
    }

    final username = widget.currentUser!.username
        .replaceAll('@', '_')
        .replaceAll('.', '_');
    final fileName = '${username}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      // Supprime l'ancienne image si existante
      if (_profilePictureUrl != null && _isValidUrl(_profilePictureUrl!)) {
        final oldFileName = _profilePictureUrl!.split('/').last;
        await _supabase.storage
            .from('profiles')
            .remove([oldFileName])
            .catchError((e) => debugPrint('Erreur suppression image : $e'));
      }

      // Upload nouvelle image
      await _supabase.storage.from('profiles').upload(fileName, file);
      final imageUrl = _supabase.storage.from('profiles').getPublicUrl(fileName);

      // Met à jour la table users
      final userResponse = await _supabase
          .from('users')
          .update({'profile_picture': imageUrl})
          .eq('id', widget.currentUser!.id)
          .select()
          .single();

      // Met à jour les posts de l'utilisateur
      await _supabase
          .from('posts')
          .update({'profile_picture': imageUrl})
          .eq('user_id', widget.currentUser!.id);

      // Rafraîchit les posts si besoin
      if (widget.refreshPosts != null) await widget.refreshPosts!();

      setState(() => _profilePictureUrl = userResponse['profile_picture']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Photo de profil mise à jour !')),
      );
    } on TimeoutException {
      _showShortError("⏰ Délai dépassé lors de l'upload");
    } on SocketException {
      _showShortError("📡 Pas de connexion Internet");
    } catch (e) {
      _showShortError("Erreur lors de l'upload", e);
    }
  }



  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: _username);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Changer le nom d’utilisateur',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Nouveau nom d’utilisateur',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final newUsername = controller.text.trim();
              if (newUsername.isEmpty) return _showShortError("Nom vide");

              try {
                await _supabase
                    .from('users')
                    .update({'username': newUsername})
                    .eq('id', widget.currentUser!.id);
                setState(() => _username = newUsername);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nom mis à jour !')));
              } catch (e) {
                _showShortError("Impossible de changer le nom", e);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }

  Future<void> _changePseudo() async {
    final controller = TextEditingController(text: _pseudo);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Changer le pseudo',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Nouveau pseudo',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final newPseudo = controller.text.trim();
              if (newPseudo.isEmpty) return _showShortError("Pseudo vide");

              try {
                await _supabase
                    .from('users')
                    .update({'pseudo': newPseudo})
                    .eq('id', widget.currentUser!.id);
                setState(() => _pseudo = newPseudo);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pseudo mis à jour !')));
              } catch (e) {
                _showShortError("Impossible de changer le pseudo", e);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }

// Helper pour afficher un message court
  void _showShortError(String message, [dynamic error]) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
    if (error != null) debugPrint('Debug detail: $error');
  }


  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showShortError("Impossible de se déconnecter", e);
    }
  }

  /// Affiche un message simple pour l'utilisateur, détail dans la console
  void _showError(String message, [dynamic error]) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
    if (error != null) debugPrint('Debug: $error');
  }



  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(icon, color: const Color(0xFF1976D2), size: 28),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 250,
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
                        CircleAvatar(
                          radius: 70,
                          backgroundImage:
                          _isValidUrl(_profilePictureUrl)
                              ? NetworkImage(_profilePictureUrl!)
                              : const AssetImage(
                              'assets/default_profile.png')
                          as ImageProvider,
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 24, color: Color(0xFF1976D2)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.settings,
                      color: Color(0xFF1976D2), size: 30),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ManageRolesPage(supabase: _supabase),
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
                  Text(_username,
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                    _pseudo.isEmpty ? 'Ajouter un pseudo' : '@$_pseudo',
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  const Text('Paramètres',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
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
                    label: Text('Déconnexion',
                        style: GoogleFonts.poppins(fontSize: 16)),
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      minimumSize:
                      const Size(double.infinity, 56),
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
