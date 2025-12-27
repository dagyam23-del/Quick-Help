import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';

/// Service for managing public comments on requests
class CommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all comments for a specific request
  Future<List<Comment>> getComments(String requestId) async {
    final response = await _supabase
        .from('comments')
        .select('*')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    // Get user IDs to fetch profile names/avatars
    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await _getProfilesByIds(userIds);

    return rows.map((json) {
      final profile = profiles[json['user_id'] as String];
      return Comment(
        id: json['id'] as String,
        requestId: json['request_id'] as String,
        userId: json['user_id'] as String,
        comment: json['comment'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        userName: profile?['name'] as String?,
        userAvatarUrl: profile?['avatar_url'] as String?,
      );
    }).toList();
  }

  /// Add a comment to a request
  Future<Comment> addComment(String requestId, String commentText) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('comments')
        .insert({
          'request_id': requestId,
          'user_id': user.id,
          'comment': commentText,
        })
        .select('*')
        .single();

    // Get user profile for name/avatar
    final profiles = await _getProfilesByIds([user.id]);
    final profile = profiles[user.id];

    return Comment(
      id: response['id'] as String,
      requestId: response['request_id'] as String,
      userId: response['user_id'] as String,
      comment: response['comment'] as String,
      createdAt: DateTime.parse(response['created_at'] as String),
      userName: profile?['name'] as String?,
      userAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  /// Delete a comment (only by the author)
  Future<void> deleteComment(String commentId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase
        .from('comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', user.id);
  }

  /// Watch comments for a request in real-time using Supabase subscriptions
  Stream<List<Comment>> watchComments(String requestId) {
    return _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at', ascending: true)
        .asyncMap((data) async {
          final rows = data
              .map((row) => Map<String, dynamic>.from(row))
              .toList();

          // Get user IDs to fetch profile names/avatars
          final userIds =
              rows.map((r) => r['user_id'] as String).toSet().toList();
          final profiles = await _getProfilesByIds(userIds);

          return rows.map((json) {
            final profile = profiles[json['user_id'] as String];
            return Comment(
              id: json['id'] as String,
              requestId: json['request_id'] as String,
              userId: json['user_id'] as String,
              comment: json['comment'] as String,
              createdAt: DateTime.parse(json['created_at'] as String),
              userName: profile?['name'] as String?,
              userAvatarUrl: profile?['avatar_url'] as String?,
            );
          }).toList();
        });
  }

  /// Helper method to get profiles by user IDs
  Future<Map<String, Map<String, dynamic>>> _getProfilesByIds(
      Iterable<String> userIds) async {
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final response = await _supabase
          .from('profiles')
          .select('id,name,avatar_url')
          .inFilter('id', ids);
      final list = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      return {for (final row in list) row['id'] as String: row};
    } catch (_) {
      // Profiles table may not exist yet, fall back to auth metadata
      final user = _supabase.auth.currentUser;
      if (user != null && ids.contains(user.id)) {
        return {
          user.id: {
            'id': user.id,
            'name': user.userMetadata?['name'] as String?,
            'avatar_url': null,
          }
        };
      }
      return {};
    }
  }
}



