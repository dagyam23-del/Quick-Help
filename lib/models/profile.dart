class Profile {
  final String id;
  final String? name;
  final String? avatarUrl;

  const Profile({
    required this.id,
    this.name,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}


