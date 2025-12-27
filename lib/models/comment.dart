/// Comment model representing a public comment on a request
class Comment {
  final String id;
  final String requestId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatarUrl;

  Comment({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.userName,
    this.userAvatarUrl,
  });

  /// Create a Comment object from JSON data
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
    );
  }

  /// Convert Comment object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'user_id': userId,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}



