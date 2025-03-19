import 'package:flutter/material.dart';
import 'dart:io'; // For file handling
import 'package:image_picker/image_picker.dart'; // For image picking
import 'user.dart'; // Import your User model

class ProfilePage extends StatefulWidget {
  final User currentUser; // Add currentUser as a parameter

  ProfilePage({required this.currentUser}); // Modify constructor

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _username;
  late String _pseudo;
  late String _profilePictureUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _username = widget.currentUser.username; // Use the currentUser data
    _pseudo = widget.currentUser.pseudo;
    _profilePictureUrl = widget.currentUser.imageUrl; // Use the currentUser data
  }

  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profilePictureUrl = pickedFile.path; // Set the new profile picture path
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 150.0,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Profile',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    GestureDetector(
                      onTap: _changeProfilePicture,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _profilePictureUrl.startsWith('http')
                            ? NetworkImage(_profilePictureUrl) // For network images
                            : FileImage(File(_profilePictureUrl)) as ImageProvider, // For local files
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _username,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '@$_pseudo',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 36),

                    // List Tiles
                    _buildSettingOption(Icons.person, 'Change User Name', () {
                      print('Change user name');
                    }),
                    _buildSettingOption(Icons.alternate_email, 'Change Pseudo', () {
                      print('Change pseudo');
                    }),
                    SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: () {
                        print('Logout');
                        Navigator.pushReplacementNamed(context, '/'); // Redirect to the welcome page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Logout'),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
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
          title: Text(title),
          trailing: Icon(Icons.arrow_forward_ios, size: 16.0),
          onTap: onTap,
        ),
      ),
    );
  }
}