import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

/// Service for managing chat messages
class MessageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all messages for a specific request
  Future<List<Message>> getMessages(String requestId) async {
    final response = await _supabase
        .from('messages')
        .select('*')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    return (response as List).map((json) {
      return Message(
        id: json['id'] as String,
        requestId: json['request_id'] as String,
        senderId: json['sender_id'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        senderName: null,
      );
    }).toList();
  }

  /// Send a message in a request chat
  Future<Message> sendMessage(String requestId, String messageText) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('messages')
        .insert({
          'request_id': requestId,
          'sender_id': user.id,
          'message': messageText,
        })
        .select('*')
        .single();

    // Get sender name from current user
    final senderName = user.userMetadata?['name'] as String?;

    return Message(
      id: response['id'] as String,
      requestId: response['request_id'] as String,
      senderId: response['sender_id'] as String,
      message: response['message'] as String,
      createdAt: DateTime.parse(response['created_at'] as String),
      senderName: senderName,
    );
  }

  /// Watch messages for a request in real-time using Supabase subscriptions
  Stream<List<Message>> watchMessages(String requestId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at', ascending: true)
        .map((data) {
          return data.map((json) {
            return Message(
              id: json['id'] as String,
              requestId: json['request_id'] as String,
              senderId: json['sender_id'] as String,
              message: json['message'] as String,
              createdAt: DateTime.parse(json['created_at'] as String),
              senderName: null,
            );
          }).toList();
        });
  }
}
