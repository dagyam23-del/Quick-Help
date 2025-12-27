import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/request_service.dart';
import '../models/request.dart';
import 'request_detail_screen.dart';

/// Profile screen showing user information and statistics
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  int _requestsCreated = 0;
  int _requestsHelped = 0;
  int _requestsCompleted = 0;
  List<Request> _userRequests = [];
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Load user profile data and statistics
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
      final requestService =
          Provider.of<RequestService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        // Ensure profile row exists (safe no-op if not configured yet)
        await authService.ensureProfile();

        final profile = await profileService.getProfile(currentUser.id);
        _avatarUrl = profile?.avatarUrl;

        // Get user's name (prefer profile name, fall back to auth metadata)
        final userName = profile?.name ?? authService.getUserName() ?? 'User';
        _nameController.text = userName;

        // Load user statistics
        final userRequests =
            await requestService.getUserRequests(currentUser.id);
        _userRequests = userRequests;

        // Count requests created by this user
        _requestsCreated =
            userRequests.where((r) => r.requesterId == currentUser.id).length;

        // Count requests where user is helper
        _requestsHelped =
            userRequests.where((r) => r.helperId == currentUser.id).length;

        // Count completed requests
        _requestsCompleted =
            userRequests.where((r) => r.status == 'completed').length;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final profileService = Provider.of<ProfileService>(context, listen: false);
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final url = await profileService.uploadMyAvatar(file);
      await profileService.upsertMyProfile(avatarUrl: url);

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _isUploadingAvatar = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Profile image updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating profile image: $e')),
      );
    }
  }

  /// Update user's name
  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        // Update user metadata in Supabase
        await authService.updateUserName(_nameController.text.trim());

        setState(() {
          _isEditingName = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text('Not logged in'),
        ),
      );
    }

    final userName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (authService.getUserName() ?? 'User');
    final userEmail = currentUser.email;
    final userPhone = currentUser.phone;

    final createdRequests =
        _userRequests.where((r) => r.requesterId == currentUser.id).toList();
    final helpedRequests =
        _userRequests.where((r) => r.helperId == currentUser.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditingName)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _updateName,
              tooltip: 'Save',
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingName = true;
                });
              },
              tooltip: 'Edit Name',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                )
                              : null,
                        ),
                        Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _isUploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isEditingName)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    )
                  else
                    Text(
                      userName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  const SizedBox(height: 8),
                  if ((userEmail ?? '').isNotEmpty)
                    Text(
                      userEmail!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    )
                  else if ((userPhone ?? '').isNotEmpty)
                    Text(
                      userPhone!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Statistics Section
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: _requestsCompleted.toString(),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.person_outline,
                    label: 'User ID',
                    value: currentUser.id.substring(0, 8),
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Requests Created Holder
            Card(
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: Colors.blue),
                ),
                title: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Requests Created',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _requestsCreated.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                    '${createdRequests.length} request${createdRequests.length != 1 ? 's' : ''}'),
                children: createdRequests.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No requests created yet.'),
                        )
                      ]
                    : createdRequests
                        .map((r) => _RequestListTile(
                              request: r,
                              onChanged: _loadProfileData,
                            ))
                        .toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Requests Helped Holder
            Card(
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.handshake_outlined, color: Colors.green),
                ),
                title: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Requests Helped',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _requestsHelped.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                    '${helpedRequests.length} request${helpedRequests.length != 1 ? 's' : ''}'),
                children: helpedRequests.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No requests helped yet.'),
                        )
                      ]
                    : helpedRequests
                        .map((r) => _RequestListTile(
                              request: r,
                              onChanged: _loadProfileData,
                            ))
                        .toList(),
              ),
            ),
            const SizedBox(height: 32),

            // Account Information
            Text(
              'Account Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  if (userEmail != null && userEmail.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(userEmail),
                    ),
                  if (userPhone != null && userPhone.isNotEmpty) ...[
                    if (userEmail != null && userEmail.isNotEmpty)
                      const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(userPhone),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Member Since'),
                    subtitle: Text(
                      _formatDate(DateTime.parse(currentUser.createdAt)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await authService.signOut();
                  if (mounted) {
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _RequestListTile extends StatelessWidget {
  final Request request;
  final Future<void> Function()? onChanged;

  const _RequestListTile({required this.request, this.onChanged});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    Color textColor;
    switch (request.status) {
      case 'open':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'taken':
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default:
        chipColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
    }

    return ListTile(
      title: Text(
        request.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        // Show the other participant (if any) so users can find their chat quickly.
        request.helperId != null
            ? 'With: ${request.helperName ?? request.requesterName ?? 'Unknown'}'
            : request.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'open', child: Text('Open')),
          PopupMenuItem(value: 'remove', child: Text('Remove from my list')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            request.status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        onSelected: (value) async {
          if (value == 'open') {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequestDetailScreen(requestId: request.id),
              ),
            );
            if (onChanged != null) await onChanged!();
          } else if (value == 'remove') {
            final requestService =
                Provider.of<RequestService>(context, listen: false);
            await requestService.archiveConversation(request.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Removed from your list.')),
              );
            }
            if (onChanged != null) await onChanged!();
          }
        },
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(requestId: request.id),
          ),
        );
        if (onChanged != null) await onChanged!();
      },
    );
  }
}

/// Stat card widget for displaying statistics
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
