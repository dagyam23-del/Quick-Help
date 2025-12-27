import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/request_service.dart';
import '../services/theme_service.dart';
import '../models/request.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

/// Home screen displaying all open help requests
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Key for RefreshIndicator
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;

  /// Manually refresh the requests list
  /// Note: Real-time updates should work automatically via Supabase streams
  /// This is just for manual refresh if needed
  Future<void> _refreshRequests() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Force a rebuild to trigger stream re-subscription
      // The stream will automatically fetch fresh data
      setState(() {});

      // Small delay to show refresh animation
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestService = Provider.of<RequestService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickHelp'),
        actions: [
          // Theme toggle button
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              return IconButton(
                icon: Icon(
                  themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeService.toggleTheme();
                },
                tooltip: themeService.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),
          // Messages button
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MessagesScreen(),
                ),
              );
            },
            tooltip: 'Messages',
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: StreamBuilder<List<Request>>(
        // Stream automatically updates in real-time when database changes
        // No key needed - stream stays active and listens to all changes
        stream: requestService.watchOpenRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No open requests',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to post a request!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshRequests,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: request.requesterAvatarUrl != null
                          ? NetworkImage(request.requesterAvatarUrl!)
                          : null,
                      child: request.requesterAvatarUrl == null
                          ? Text(
                              (request.requesterName ?? 'U').trim().isNotEmpty
                                  ? (request.requesterName ?? 'U')
                                      .trim()[0]
                                      .toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      request.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(request.description),
                        const SizedBox(height: 4),
                        Text(
                          'By: ${request.requesterName ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RequestDetailScreen(
                            requestId: request.id,
                          ),
                        ),
                      ).then((_) {
                        // Ensure list reflects any changes done in detail screen
                        // (e.g. request taken) even if requests realtime is not enabled.
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateRequestScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }
}
