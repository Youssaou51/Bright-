class User {
  final String id;
  final String username;
  final String pseudo;
  final String imageUrl;

  User({
    required this.id,
    required this.username,
    required this.pseudo,
    required this.imageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      pseudo: json['pseudo'] as String,
      imageUrl: json['image_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'pseudo': pseudo,
      'image_url': imageUrl,
    };
  }
}