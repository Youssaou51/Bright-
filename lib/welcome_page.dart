import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'login_page.dart';
import 'signup_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Hero(
                                tag: 'app-logo',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/bright_future_foundation.jpg',
                                    height: size.height * 0.25,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Welcome to Bright Future',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: size.width * 0.065,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join our community to make a difference',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: size.width * 0.04,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          _buildButton(
                            context,
                            label: 'Log In',
                            backgroundColor: Colors.white,
                            textColor: Colors.grey.shade800,
                            borderColor: Colors.grey.shade300,
                            onPressed: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => LoginPage(),
                                transitionsBuilder:
                                    (_, animation, __, child) => FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildButton(
                            context,
                            label: 'Sign Up',
                            backgroundColor: Colors.grey.shade800,
                            textColor: Colors.white,
                            onPressed: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => SignupPage(),
                                transitionsBuilder:
                                    (_, animation, __, child) => FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade500,
                            ),
                            child: const Text(
                              'Continue as Guest',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, {
        required String label,
        required Color backgroundColor,
        required Color textColor,
        Color? borderColor,
        required VoidCallback onPressed,
      }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null
                ? BorderSide(color: borderColor, width: 1)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
