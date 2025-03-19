import 'package:flutter/material.dart'; // Needed for Flutter widgets
import 'dart:io'; // For file handling if using File
import 'user.dart'; // Import your User model
import 'post.dart'; // Import your Post model
import 'comments_page.dart'; // Import the CommentsPage

class HomePage extends StatefulWidget {
  final List<Post> posts;
  final User currentUser;

  HomePage({required this.posts, required this.currentUser}); // Constructor

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Track liked posts
  Set<int> likedPosts = {};

  List<Post> _sortPosts(List<Post> posts) {
    return posts..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _toggleLike(int index) {
    setState(() {
      if (likedPosts.contains(index)) {
        likedPosts.remove(index);
        widget.posts[index].likesCount = (widget.posts[index].likesCount > 0)
            ? widget.posts[index].likesCount - 1
            : 0; // Prevent negative likes
      } else {
        likedPosts.add(index);
        widget.posts[index].likesCount++; // Increment like count
      }
    });
  }

  void _showCommentsPage(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return CommentsPage(
          post: post,
          currentUserName: widget.currentUser.username,
          currentUserImageUrl: widget.currentUser.imageUrl,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedPosts = _sortPosts(widget.posts);

    return ListView.builder(
      itemCount: sortedPosts.length,
      itemBuilder: (context, index) {
        Post post = sortedPosts[index];
        bool isLiked = likedPosts.contains(index); // Check if the post is liked

        return Container(
          margin: EdgeInsets.symmetric(vertical: 2.0), // Vertical spacing between posts
          color: Colors.white, // Set background color to white
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Reduced padding
                minVerticalPadding: 2.0, // Minimum vertical padding
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(widget.currentUser.imageUrl),
                ),
                title: Text(
                  widget.currentUser.pseudo, // Display only pseudo
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), // Reduced font size
                ),
                // Removed subtitle to show only profile picture and pseudo
              ),
              Container(
                height: 400, // Height for images
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.images.length,
                  itemBuilder: (context, imageIndex) {
                    File image = post.images[imageIndex];
                    return GestureDetector(
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: MediaQuery.of(context).size.width, // Full width of the screen
                        height: 400, // Match height to container
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(post.caption),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Align icons to the start
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black, // Change color based on state
                      ),
                      onPressed: () {
                        _toggleLike(index); // Toggle like functionality
                      },
                    ),
                    Text(
                      '${post.likesCount}', // Show like count
                      style: TextStyle(fontSize: 16, color: Colors.black), // Adjust style as needed
                    ),
                    SizedBox(width: 16), // Add space between like and comment icons
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // White background for the comment icon
                        shape: BoxShape.circle, // Circular shape
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chat, color: Colors.black), // Use chat icon for comments
                        onPressed: () {
                          // Show comments page
                          _showCommentsPage(post);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}