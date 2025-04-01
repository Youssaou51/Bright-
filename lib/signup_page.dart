import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'dashboard_page.dart';
import 'user.dart' as local; // Alias for your local User class

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Sign up with Supabase
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Get the authenticated user
      final user = response.user;

      if (user != null) {
        // Navigate to the dashboard after successful signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              currentUser: local.User(
                id: user.id, // Use the user ID from the response
                username: _usernameController.text,
                pseudo: _usernameController.text,
                imageUrl: "https://via.placeholder.com/150",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing up: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Image.asset('assets/images/bright_future_foundation.jpg', height: 300),
                  Text(
                    'Create an Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 40),
                  // Username Input
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Choose a username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Email Input
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Password Input
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 30),
                  // Signup Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _signUp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      textStyle: TextStyle(fontSize: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Signup'),
                  ),
                  SizedBox(height: 20),
                  // Terms and Conditions (Example)
                  TextButton(
                    onPressed: () {
                      // Handle terms and conditions logic
                      print("Terms and Conditions pressed");
                    },
                    child: Text(
                      'By signing up, you agree to our Terms & Conditions',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  Spacer(), // Pushes content up to avoid overlap with bottom
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}