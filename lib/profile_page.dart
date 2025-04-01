import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'user.dart' as localUser; // Alias for your local User class

class ProfilePage extends StatefulWidget {
  final localUser.User? currentUser; // Use the aliased User class

  ProfilePage({this.currentUser});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _username;
  late String _pseudo;
  late String _profilePictureUrl;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client; // Supabase client

  @override
  void initState() {
    super.initState();
    _username = widget.currentUser?.username ?? '';
    _pseudo = widget.currentUser?.pseudo ?? '';
    _profilePictureUrl = widget.currentUser?.imageUrl ?? '';
  }

  Future<void> _changeProfilePicture() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.black87),
                title: Text("Choose from Gallery"),
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
                leading: Icon(Icons.camera_alt, color: Colors.black87),
                title: Text("Take a Picture"),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile =
                  await _picker.pickImage(source: ImageSource.camera);
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
    final fileName = '${widget.currentUser?.username}_profile.jpg';
    try {
      final response = await _supabase.storage
          .from('profile_pictures')
          .upload(fileName, file);

      final imageUrl = _supabase.storage
          .from('profile_pictures')
          .getPublicUrl(fileName);

      await _supabase.from('profiles').update({
        'image_url': imageUrl,
        'id': widget.currentUser?.id,
        'pseudo' : _pseudo,
      });

      setState(() {
        _profilePictureUrl = imageUrl;
      });
    } on StorageException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${error.message}')),
      );
    }
  }

  Future<void> _changePseudo() async {
    TextEditingController pseudoController =
    TextEditingController(text: _pseudo);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text("Change Pseudo",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              TextField(
                controller: pseudoController,
                decoration: InputDecoration(
                  hintText: "Enter new pseudo",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pseudo = pseudoController.text;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Center(
                    child: Text("Save", style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut(); // Sign out using Supabase
      Navigator.pushReplacementNamed(context, '/'); // Navigate to the login page
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0), // Use named parameter
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: _changeProfilePicture,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _profilePictureUrl.startsWith('http')
                    ? NetworkImage(_profilePictureUrl) // Network image
                    : FileImage(File(_profilePictureUrl)) as ImageProvider, // Local image
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(Icons.camera_alt, color: Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              _username,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 8),
            Text(
              '@$_pseudo',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 36),
            _buildSettingOption(Icons.person, 'Change User Name', () {
              print('Change user name');
            }),
            _buildSettingOption(Icons.alternate_email, 'Change Pseudo', _changePseudo),
            SizedBox(height: 36),
            ElevatedButton(
              onPressed: _signOut, // Call the sign-out method
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.black54),
          title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          onTap: onTap,
        ),
      ),
    );
  }
}