import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import 'user.dart' as local;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _signIn(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;
      if (user != null) {
        // 🔍 Check if the user is active in the 'users' table
        final userData = await Supabase.instance.client
            .from('users')
            .select('is_active, username, profile_picture')
            .eq('id', user.id)
            .maybeSingle();

        final isActive = userData?['is_active'] ?? false;

        if (!isActive) {
          // 🛑 User not yet approved by admin
          await Supabase.instance.client.auth.signOut(); // logout
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Your account is not yet activated. Please wait for admin approval."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // ✅ User is active, navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              currentUser: local.User(
                id: user.id,
                username: userData?['username'] ?? user.email ?? 'User',
                pseudo: userData?['username'] ?? user.email ?? 'User',
                imageUrl: userData?['avatar_url'] ?? "https://via.placeholder.com/150",
              ),
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      final isInvalid = e.message.toLowerCase().contains('invalid login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInvalid ? 'Invalid email or password.' : 'Auth Error: ${e.message}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/bright_future_foundation.jpg', height: 200),
                    const SizedBox(height: 30),
                    Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email', 'Enter your email'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: _inputDecoration('Password', 'Enter your password'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Password is required';
                        if (value.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _signIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(fontSize: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login'),
                    ),

                    const SizedBox(height: 20),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Reset password feature coming soon!')),
                          );
                        },
                        child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue)),
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
