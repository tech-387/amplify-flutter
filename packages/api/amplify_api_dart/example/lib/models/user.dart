class User {
  final String id;

  /// The current user's description (about section).
  final String? description;

  User({required this.id, required this.description});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, description: $description}';
  }
}
