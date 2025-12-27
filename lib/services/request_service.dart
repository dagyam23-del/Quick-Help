import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request.dart';

/// Service for managing help requests (CRUD operations)
class RequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, Map<String, dynamic>>> _getProfilesByIds(
      Iterable<String> userIds) async {
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final response = await _supabase
          .from('profiles')
          .select('id,name,avatar_url')
          .inFilter(
            'id',
            ids,
          );
      final list = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      return {for (final row in list) row['id'] as String: row};
    } catch (_) {
      // Profiles table may not exist yet.
      return {};
    }
  }

  Future<List<String>> _getArchivedRequestIdsForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('request_archives')
        .select('request_id')
        .eq('user_id', user.id);

    return (response as List)
        .map((row) => row['request_id'] as String)
        .toList();
  }

  /// Get all open requests (available for volunteers)
  /// Shows both 'open' and 'taken' requests - only 'completed' and 'deleted' requests are hidden
  Future<List<Request>> getOpenRequests() async {
    final response = await _supabase.from('requests').select('*').inFilter(
        'status', ['open', 'taken']).order('created_at', ascending: false);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    // Get all user IDs (requesters and helpers)
    final userIds = <String>{};
    for (final r in rows) {
      userIds.add(r['requester_id'] as String);
      final helperId = r['helper_id'] as String?;
      if (helperId != null) userIds.add(helperId);
    }
    final profiles = await _getProfilesByIds(userIds);

    return rows.map((json) {
      final requesterProfile = profiles[json['requester_id'] as String];
      final helperId = json['helper_id'] as String?;
      final helperProfile = helperId != null ? profiles[helperId] : null;

      return Request(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        status: json['status'] as String,
        requesterId: json['requester_id'] as String,
        helperId: helperId,
        createdAt: DateTime.parse(json['created_at'] as String),
        requesterName: requesterProfile?['name'] as String?,
        helperName: helperProfile?['name'] as String?,
        requesterAvatarUrl: requesterProfile?['avatar_url'] as String?,
        helperAvatarUrl: helperProfile?['avatar_url'] as String?,
      );
    }).toList();
  }

  /// Get all requests for a specific user (for profile statistics)
  Future<List<Request>> getUserRequests(String userId) async {
    final archivedIds = await _getArchivedRequestIdsForCurrentUser();

    var query = _supabase
        .from('requests')
        .select('*')
        .or('requester_id.eq.$userId,helper_id.eq.$userId');

    // Hide conversations the current user archived (soft-delete).
    if (archivedIds.isNotEmpty) {
      query = query.not('id', 'in', '(${archivedIds.join(',')})');
    }

    final response = await query.order('created_at', ascending: false);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final ids = <String>{};
    for (final r in rows) {
      ids.add(r['requester_id'] as String);
      final helper = r['helper_id'] as String?;
      if (helper != null) ids.add(helper);
    }
    final profiles = await _getProfilesByIds(ids);

    return rows.map((json) {
      final requesterProfile = profiles[json['requester_id'] as String];
      final helperId = json['helper_id'] as String?;
      final helperProfile = helperId == null ? null : profiles[helperId];
      return Request(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        status: json['status'] as String,
        requesterId: json['requester_id'] as String,
        helperId: helperId,
        createdAt: DateTime.parse(json['created_at'] as String),
        requesterName: requesterProfile?['name'] as String?,
        helperName: helperProfile?['name'] as String?,
        requesterAvatarUrl: requesterProfile?['avatar_url'] as String?,
        helperAvatarUrl: helperProfile?['avatar_url'] as String?,
      );
    }).toList();
  }

  /// Get a specific request by ID
  Future<Request?> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('*')
          .eq('id', requestId)
          .single();

      final requesterId = response['requester_id'] as String;
      final helperId = response['helper_id'] as String?;
      final profileIds = <String>{requesterId};
      if (helperId != null) profileIds.add(helperId);
      final profiles = await _getProfilesByIds(profileIds);
      final requesterProfile = profiles[requesterId];
      final helperProfile = helperId == null ? null : profiles[helperId];

      return Request(
        id: response['id'] as String,
        title: response['title'] as String,
        description: response['description'] as String,
        status: response['status'] as String,
        requesterId: requesterId,
        helperId: helperId,
        createdAt: DateTime.parse(response['created_at'] as String),
        requesterName: requesterProfile?['name'] as String?,
        helperName: helperProfile?['name'] as String?,
        requesterAvatarUrl: requesterProfile?['avatar_url'] as String?,
        helperAvatarUrl: helperProfile?['avatar_url'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create a new help request
  Future<Request> createRequest(String title, String description) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Insert the request
    final insertResponse = await _supabase.from('requests').insert({
      'title': title,
      'description': description,
      'status': 'open',
      'requester_id': user.id,
    });

    // Extract the inserted row from response
    Map<String, dynamic> responseData;
    if (insertResponse is List && insertResponse.isNotEmpty) {
      responseData = Map<String, dynamic>.from(insertResponse.first);
    } else if (insertResponse is Map) {
      responseData = Map<String, dynamic>.from(insertResponse);
    } else {
      // Fallback: fetch the most recent request by this user
      await Future.delayed(const Duration(milliseconds: 100));
      final fetchResponse = await _supabase
          .from('requests')
          .select()
          .eq('requester_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      responseData = Map<String, dynamic>.from(fetchResponse);
    }

    // Get requester name from current user
    final requesterName = user.userMetadata?['name'] as String?;

    return Request(
      id: responseData['id'] as String,
      title: responseData['title'] as String,
      description: responseData['description'] as String,
      status: responseData['status'] as String,
      requesterId: responseData['requester_id'] as String,
      helperId: responseData['helper_id'] as String?,
      createdAt: DateTime.parse(responseData['created_at'] as String),
      requesterName: requesterName,
    );
  }

  /// Volunteer to help with a request
  /// Changes status from 'open' to 'taken' and assigns helper_id
  Future<void> volunteerForRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Only take the request if it's still open (prevents overwriting if someone else took it).
    final response = await _supabase
        .from('requests')
        .update({
          'helper_id': user.id,
          'status': 'taken',
        })
        .eq('id', requestId)
        .eq('status', 'open')
        .select('id');

    final rows = response as List;
    if (rows.isEmpty) {
      throw Exception('This request was already taken by someone else.');
    }
  }

  /// Mark a request as completed
  Future<void> completeRequest(String requestId) async {
    await _supabase
        .from('requests')
        .update({'status': 'completed'}).eq('id', requestId);
  }

  /// Watch open requests in real-time using Supabase subscriptions
  /// Automatically updates when requests are created, updated, or deleted
  /// Note: Make sure Realtime is enabled for the 'requests' table in Supabase Dashboard
  Stream<List<Request>> watchOpenRequests() {
    // NOTE: Realtime replication for `requests` is optional in Supabase.
    // If it's not enabled, `.stream()` will NOT update when a request becomes 'taken'.
    // To keep UX correct (accepted requests disappear quickly), we poll.
    return _watchOpenRequestsByPolling();
  }

  Stream<List<Request>> _watchOpenRequestsByPolling(
      {Duration interval = const Duration(seconds: 5)}) async* {
    yield await getOpenRequests();
    yield* Stream.periodic(interval).asyncMap((_) => getOpenRequests());
  }

  /// Archive (soft-delete) a conversation for the current user.
  /// This does NOT delete the request/messages; it only hides it from the user's lists.
  Future<void> archiveConversation(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.from('request_archives').upsert({
      'request_id': requestId,
      'user_id': user.id,
    });
  }

  /// Unarchive a conversation for the current user.
  Future<void> unarchiveConversation(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase
        .from('request_archives')
        .delete()
        .eq('request_id', requestId)
        .eq('user_id', user.id);
  }

  /// Delete a request (only the requester can delete their own request)
  /// This removes it from the main screen for everyone
  Future<void> deleteRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // First check if the current user is the requester
    final request = await getRequestById(requestId);
    if (request == null) {
      throw Exception('Request not found');
    }
    if (request.requesterId != user.id) {
      throw Exception('Only the requester can delete this request');
    }

    // Set status to 'deleted' instead of actually deleting (preserves data)
    await _supabase
        .from('requests')
        .update({'status': 'deleted'})
        .eq('id', requestId)
        .eq('requester_id', user.id);
  }
}
