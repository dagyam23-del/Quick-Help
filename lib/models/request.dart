/// Request model representing a help request
/// Each request has a requester (person who needs help) and optionally a helper
class Request {
  final String id;
  final String title;
  final String description;
  final String status; // 'open', 'taken', 'completed'
  final String requesterId;
  final String? helperId;
  final DateTime createdAt;
  final String? requesterName;
  final String? helperName;
  final String? requesterAvatarUrl;
  final String? helperAvatarUrl;

  Request({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.requesterId,
    this.helperId,
    required this.createdAt,
    this.requesterName,
    this.helperName,
    this.requesterAvatarUrl,
    this.helperAvatarUrl,
  });

  /// Create a Request object from JSON data
  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      requesterId: json['requester_id'] as String,
      helperId: json['helper_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      requesterName: json['requester_name'] as String?,
      helperName: json['helper_name'] as String?,
      requesterAvatarUrl: json['requester_avatar_url'] as String?,
      helperAvatarUrl: json['helper_avatar_url'] as String?,
    );
  }

  /// Convert Request object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'requester_id': requesterId,
      'helper_id': helperId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if request is open (available for volunteers)
  bool get isOpen => status == 'open';

  /// Check if request is taken (has a helper)
  bool get isTaken => status == 'taken';

  /// Check if request is completed
  bool get isCompleted => status == 'completed';
}
