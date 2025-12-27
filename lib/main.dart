import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/request_service.dart';
import 'services/message_service.dart';
import 'services/comment_service.dart';
import 'services/profile_service.dart';
import 'services/theme_service.dart';
import 'services/file_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';

/// QuickHelp - Micro-Volunteering App
/// Main entry point for the Flutter application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase connection
  // TODO: Replace with your Supabase project credentials
  const supabaseUrl = 'https://qwhsnclffnuhmmxseunr.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3aHNuY2xmZm51aG1teHNldW5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY1MDg2OTAsImV4cCI6MjA4MjA4NDY5MH0.1FmQT8BzBLb0PXtw7L9YO-z-ep9ZulW1OargsDcKt7U';

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Handle email confirmation callback from URL (for web only)
    // Note: Web URL handling is done automatically by Supabase SDK
    // No need for manual URL parsing on mobile

    runApp(QuickHelpApp(notificationService: notificationService));
  } catch (e) {
    runApp(ConfigurationErrorApp(error: e.toString()));
  }
}

/// Main app widget
class QuickHelpApp extends StatelessWidget {
  final NotificationService notificationService;

  const QuickHelpApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => RequestService()),
        Provider(create: (_) => MessageService()),
        Provider(create: (_) => CommentService()),
        Provider(create: (_) => ProfileService()),
        Provider(create: (_) => FileService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'QuickHelp',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeService.themeMode,
            home: AuthWrapper(notificationService: notificationService),
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
            },
            onGenerateRoute: (settings) {
              // Handle password reset callback from URL
              if (settings.name == '/reset-password' ||
                  (kIsWeb && Uri.base.path == '/reset-password')) {
                return MaterialPageRoute(
                  builder: (context) => const ResetPasswordScreen(),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Wrapper that handles authentication state
/// Shows HomeScreen if user is logged in, AuthScreen otherwise
class AuthWrapper extends StatefulWidget {
  final NotificationService notificationService;

  const AuthWrapper({super.key, required this.notificationService});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Handle password reset callback from URL (web only)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePasswordResetCallback();
      });
    }

    // Start listening for notifications when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final requestService =
          Provider.of<RequestService>(context, listen: false);
      widget.notificationService.startListening(authService, requestService);
    });
  }

  /// Handle password reset callback from email link
  Future<void> _handlePasswordResetCallback() async {
    if (!kIsWeb) return;

    // Wait a bit for Supabase to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    final uri = Uri.base;
    final hash = uri.fragment;

    // Check if URL contains password reset token in hash or path
    // Supabase reset links can be: /reset-password#access_token=...&type=recovery
    // OR just the root with hash: #access_token=...&type=recovery
    final isResetPath = uri.path == '/reset-password' || uri.path.endsWith('/reset-password');
    final hasRecoveryType = hash.contains('type=recovery') ||
                           hash.contains('access_token') ||
                           (uri.queryParameters.containsKey('type') &&
                            uri.queryParameters['type'] == 'recovery');

    // Debug logging
    if (kDebugMode) {
      debugPrint('Reset callback - Path: ${uri.path}, Hash: $hash, HasRecovery: $hasRecoveryType');
    }

    if (isResetPath || hasRecoveryType) {
      // Explicitly get session from URL hash fragment
      try {
        final supabase = Supabase.instance.client;

        // Get session from URL (handles hash fragments)
        await supabase.auth.getSessionFromUrl(uri);

        // Add delay to ensure session is set before navigation
        await Future.delayed(const Duration(milliseconds: 300));

        // Navigate to reset password screen immediately
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/reset-password');
        }
      } catch (e) {
        // Error recovering session, navigate anyway - user will see error on screen
        if (kDebugMode) {
          debugPrint('Error recovering session: $e');
        }
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/reset-password');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Check if we're on the reset password path (web only)
        if (kIsWeb) {
          final uri = Uri.base;
          final hash = uri.fragment;
          // Check path OR hash fragments (Supabase might redirect to root with hash)
          final isResetPath = uri.path == '/reset-password' || uri.path.endsWith('/reset-password');
          // Check for recovery tokens in hash (even if path is root)
          final hasRecoveryType = hash.contains('type=recovery') || 
                                 hash.contains('access_token') ||
                                 hash.contains('type=password') ||
                                 uri.queryParameters.containsKey('type') &&
                                 uri.queryParameters['type'] == 'recovery';
          
          if (kDebugMode && (isResetPath || hasRecoveryType)) {
            debugPrint('StreamBuilder - Showing ResetPasswordScreen. Path: ${uri.path}, Hash: ${hash.substring(0, hash.length > 50 ? 50 : hash.length)}...');
          }
          
          if (isResetPath || hasRecoveryType) {
            // Always show reset password screen when on reset path or has recovery hash
            return const ResetPasswordScreen();
          }
        }
        
        if (snapshot.hasData) {
          final session = snapshot.data?.session;

          if (session != null) {
            // Restart notification listening when user logs in
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final requestService =
                  Provider.of<RequestService>(context, listen: false);
              widget.notificationService
                  .startListening(authService, requestService);
            });
            return const HomeScreen();
          }
        }
        return const AuthScreen();
      },
    );
  }
}

/// Error screen shown when Supabase configuration is missing
class ConfigurationErrorApp extends StatelessWidget {
  final String? error;

  const ConfigurationErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickHelp - Configuration Required',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Supabase Configuration Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To use this app, you need to configure Supabase credentials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Setup Instructions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                              '1. Go to supabase.com and create a project'),
                          const SizedBox(height: 8),
                          const Text(
                              '2. Run the SQL from supabase_setup.sql in SQL Editor'),
                          const SizedBox(height: 8),
                          const Text(
                              '3. Get your Project URL and anon key from Settings > API'),
                          const SizedBox(height: 8),
                          const Text('4. Open lib/main.dart and replace:'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'YOUR_SUPABASE_URL\nYOUR_SUPABASE_ANON_KEY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('5. Restart the app'),
                        ],
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Error: $error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
