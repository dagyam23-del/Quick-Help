/// Message model representing a chat message in a request
/// Messages are tied to a specific request and have a sender
class Message {
  final String id;
  final String requestId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String? senderName;

  Message({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.senderName,
  });

  /// Create a Message object from JSON data
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
    );
  }

  /// Convert Message object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'sender_id': senderId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
