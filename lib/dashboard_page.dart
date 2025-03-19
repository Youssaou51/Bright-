import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'reports_page.dart';
import 'home_page.dart';
import 'dart:io';
import 'profile_page.dart';
import 'tasks_page.dart';
import 'post.dart'; // Ensure you have the Post model imported
import 'user.dart'; // Import your User model

class DashboardPage extends StatefulWidget {
  final User currentUser; // Add currentUser as a parameter

  DashboardPage({required this.currentUser}); // Modify constructor

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final PageController _pageController = PageController(initialPage: 0);
  final ImagePicker _picker = ImagePicker();

  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this, // This refers to the TickerProvider
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset(0, -0.2))
        .animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
              ListTile(
                leading: Icon(Icons.camera, color: Colors.blue),
                title: Text('Take a Picture'),
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
                title: Text('Select from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    _promptForCaption([File(pickedFile.path)], [], "New Photo Post");
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: Colors.blue),
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
                leading: Icon(Icons.video_library, color: Colors.blue),
                title: Text('Select Video from Gallery'),
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
    String caption = defaultCaption; // Initialize caption with the default
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Caption'),
          content: Container(
            width: double.maxFinite, // Ensure the container uses full width
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Display the selected media
                if (images.isNotEmpty)
                  Image.file(images[0], fit: BoxFit.cover, width: double.maxFinite),
                if (videos.isNotEmpty)
                  Container(
                    height: 200,
                    color: Colors.black,
                    child: Center(child: Text('Video Placeholder', style: TextStyle(color: Colors.white))),
                  ),
                // TextField overlay
                Positioned(
                  bottom: 20, // Adjust this value to position the TextField
                  left: 16,
                  right: 16,
                  child: TextField(
                    onChanged: (value) {
                      caption = value; // Update caption as user types
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter caption...',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8), // Slightly transparent background
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none, // Remove border
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
                Navigator.of(context).pop(); // Close the dialog
                _addPost(images, videos, caption); // Add the post with the caption
              },
              child: Text('Submit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _addPost(List<File> images, List<File> videos, String caption) {
    setState(() {
      _posts.add(Post(
        images: images,
        videos: videos,
        caption: caption,
        timestamp: DateTime.now(),
        likesCount: 0,
        comments: [], // Initialize comments list
      ));
      // Sort posts by timestamp in descending order (newest first)
      _posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
              onPageChanged: _onPageChanged,
              physics: NeverScrollableScrollPhysics(),
              children: <Widget>[
                HomePage(posts: _posts, currentUser: widget.currentUser), // Pass currentUser
                ReportsPage(),
                Container(), // Placeholder for the media icon action
                TasksPage(),
                ProfilePage(currentUser: widget.currentUser), // Pass currentUser here
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.fileAlt),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.image), // Media Icon
              label: 'Media',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.tasks),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}