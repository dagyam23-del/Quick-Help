import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/request_service.dart';

/// Service for handling local notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  final Set<String> _processedCommentIds = {};
  final Set<String> _processedMessageIds = {};

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Request permissions
    await _requestPermissions();

    _isInitialized = true;
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'quickhelp_channel',
      'QuickHelp Notifications',
      description: 'Notifications for comments and messages',
      importance: Importance.high,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation if needed
  }

  /// Show a notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'quickhelp_channel',
      'QuickHelp Notifications',
      channelDescription: 'Notifications for comments and messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Start listening for comments and messages
  void startListening(AuthService authService, RequestService requestService) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Listen for new comments on user's requests
    _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .listen((data) async {
      for (final comment in data) {
        final commentData = Map<String, dynamic>.from(comment);
        final commentId = commentData['id'] as String;
        final requestId = commentData['request_id'] as String;
        final userId = commentData['user_id'] as String;

        // Skip if already processed
        if (_processedCommentIds.contains(commentId)) continue;
        _processedCommentIds.add(commentId);

        // Skip if comment is from current user
        if (userId == currentUser.id) continue;

        // Check if this is the requester's request
        try {
          final request = await requestService.getRequestById(requestId);
          if (request != null && request.requesterId == currentUser.id) {
            await showNotification(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              title: 'New Comment',
              body: 'Someone commented on your request: ${request.title}',
              payload: requestId,
            );
          }
        } catch (e) {
          // Ignore errors
        }
      }
    });

    // Listen for new messages
    _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((data) async {
      for (final message in data) {
        final messageData = Map<String, dynamic>.from(message);
        final messageId = messageData['id'] as String;
        final requestId = messageData['request_id'] as String;
        final senderId = messageData['sender_id'] as String;
        final messageText = messageData['message'] as String;

        // Skip if already processed
        if (_processedMessageIds.contains(messageId)) continue;
        _processedMessageIds.add(messageId);

        // Skip if message is from current user
        if (senderId == currentUser.id) continue;

        // Check if current user is requester or helper
        try {
          final request = await requestService.getRequestById(requestId);
          if (request != null) {
            final isRequester = request.requesterId == currentUser.id;
            final isHelper = request.helperId == currentUser.id;

            if (isRequester || isHelper) {
              final otherUserName = isRequester
                  ? (request.helperName ?? 'Helper')
                  : (request.requesterName ?? 'Requester');

              await showNotification(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                title: 'New Message',
                body: '$otherUserName: ${messageText.length > 50 ? "${messageText.substring(0, 50)}..." : messageText}',
                payload: requestId,
              );
            }
          }
        } catch (e) {
          // Ignore errors
        }
      }
    });
  }

  /// Clear processed IDs (useful when user logs out)
  void clearProcessedIds() {
    _processedCommentIds.clear();
    _processedMessageIds.clear();
  }
}

