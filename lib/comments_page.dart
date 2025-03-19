import 'package:flutter/material.dart';
import 'post.dart'; // Import your Post model
import 'comment.dart'; // Import your Comment model

class CommentsPage extends StatefulWidget {
  final Post post;
  final String currentUserName;
  final String currentUserImageUrl;

  CommentsPage({
    required this.post,
    required this.currentUserName,
    required this.currentUserImageUrl,
  });

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _addComment() {
    if (_commentController.text.isNotEmpty) {
      // Create a new comment
      Comment newComment = Comment(
        username: widget.currentUserName,
        userImageUrl: widget.currentUserImageUrl,
        content: _commentController.text,
        timestamp: DateTime.now(),
      );

      // Add the new comment to the post
      setState(() {
        widget.post.comments.add(newComment);
      });

      // Clear the text field
      _commentController.clear();

      // Scroll to the bottom of the comments
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // Delay the scrolling to ensure the new comment is rendered
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Centered App Bar
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Text(
              'Comments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          // Scrollable Comment List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.post.comments.length,
              itemBuilder: (context, index) {
                final comment = widget.post.comments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(comment.userImageUrl),
                      ),
                      title: Text(
                        comment.username,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(comment.content),
                    ),
                  ),
                );
              },
            ),
          ),
          // Comment Input Area (remains at the bottom)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    ),
                    onSubmitted: (value) {
                      _addComment();
                    },
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue), // Set send button color to blue
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}