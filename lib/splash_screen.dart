import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget? nextScreen; // <-- nullable maintenant

  const SplashScreen({super.key, this.nextScreen}); // <-- supprimé "required"

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Attente de 2 secondes avant navigation
    Future.delayed(const Duration(seconds: 5), () {
      if (widget.nextScreen != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextScreen!),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/bright_future_foundation.jpg'),
            const SizedBox(height: 20),
            const Text(
              'Bright Future Foundation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(), // un petit loader
          ],
        ),
      ),
    );
  }
}
