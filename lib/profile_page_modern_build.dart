// NOUVELLE VERSION MODERNE DE LA PAGE PROFILE
// Remplacer la méthode build() dans lib/profile_page.dart par ce code

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1976D2)),
          )
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1976D2),
                  Color(0xFF1565C0),
                  Colors.white,
                ],
                stops: [0