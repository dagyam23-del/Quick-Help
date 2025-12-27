import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/request_service.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../services/file_service.dart';
import '../models/request.dart';
import '../models/comment.dart';
import '../models/request_file.dart';
import 'chat_screen.dart';

/// Screen showing request details, volunteer button, and chat
class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _commentController = TextEditingController();
  final _commentScrollController = ScrollController();
  Request? _request;
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _commentsExpanded = false;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentScrollController.dispose();
    super.dispose();
  }

  /// Load request details from the database
  Future<void> _loadRequest() async {
    try {
      final requestService =
          Provider.of<RequestService>(context, listen: false);
      final request = await requestService.getRequestById(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading request: $e')),
        );
      }
    }
  }

  /// Volunteer to help with this request
  Future<void> _volunteer() async {
    try {
      final requestService =
          Provider.of<RequestService>(context, listen: false);
      await requestService.volunteerForRequest(widget.requestId);
      await _loadRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You volunteered to help!')),
        );
        // Navigate to private chat screen after volunteering
        if (_request != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(request: _request!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }


  /// Mark request as completed
  Future<void> _completeRequest() async {
    try {
      final requestService =
          Provider.of<RequestService>(context, listen: false);
      await requestService.completeRequest(widget.requestId);
      await _loadRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request marked as completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Check if current user can chat (must be requester or helper)
  bool _canChat() {
    if (_request == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    if (currentUserId == null) return false;

    // Allow chat for both 'taken' and 'completed' so the conversation persists
    // until each user chooses to delete/archive it from their own list.
    return (_request!.status == 'taken' || _request!.status == 'completed') &&
        (currentUserId == _request!.requesterId ||
            currentUserId == _request!.helperId);
  }

  /// Check if current user can volunteer
  bool _canVolunteer() {
    if (_request == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    if (currentUserId == null) return false;

    return _request!.status == 'open' &&
        currentUserId != _request!.requesterId;
  }

  /// Check if current user can mark request as completed
  bool _canComplete() {
    if (_request == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id;
    if (currentUserId == null) return false;

    return _request!.status == 'taken' &&
        (currentUserId == _request!.requesterId ||
            currentUserId == _request!.helperId);
  }

  /// Add a comment to the request
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSendingComment = true;
    });

    try {
      final commentService =
          Provider.of<CommentService>(context, listen: false);
      await commentService.addComment(
        widget.requestId,
        _commentController.text.trim(),
      );
      _commentController.clear();
      // Auto-scroll to bottom when new comment is added
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_commentScrollController.hasClients) {
          _commentScrollController.animateTo(
            _commentScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  /// Delete a comment (only by the author)
  Future<void> _deleteComment(String commentId) async {
    try {
      final commentService =
          Provider.of<CommentService>(context, listen: false);
      await commentService.deleteComment(commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  /// Upload a file for helpers
  Future<void> _uploadFile() async {
    try {
      setState(() {
        _isUploadingFile = true;
      });

      final fileService = Provider.of<FileService>(context, listen: false);
      
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploadingFile = false;
        });
        return;
      }

      final file = result.files.first;
      await fileService.uploadFile(widget.requestId, file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File "${file.name}" uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  /// Delete a file
  Future<void> _deleteFile(String fileId) async {
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      await fileService.deleteFile(fileId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
    }
  }

  /// Download/open a file
  Future<void> _openFile(RequestFile file) async {
    try {
      final fileService = Provider.of<FileService>(context, listen: false);
      final url = fileService.getFileUrl(file.filePath);
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.id;
    final requestService = Provider.of<RequestService>(context, listen: false);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: Text('Request not found')),
      );
    }

    final canChat = _canChat();
    final canVolunteer = _canVolunteer();
    final canComplete = _canComplete();
    final canDelete = currentUserId != null &&
        currentUserId == _request!.requesterId &&
        _request!.status != 'deleted';
    final isRequester = currentUserId != null &&
        currentUserId == _request!.requesterId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              if (value == 'delete') {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Request'),
                    content: const Text(
                      'Are you sure you want to delete this request? This will remove it from the main screen for everyone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true && mounted) {
                  try {
                    await requestService.deleteRequest(widget.requestId);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Request deleted successfully.'),
                        ),
                      );
                      navigator.pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              if (canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Request'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Request Details Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _request!.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _request!.status == 'open'
                          ? Colors.green.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.2)
                          : _request!.status == 'taken'
                              ? Colors.orange.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.2)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _request!.status.toUpperCase(),
                      style: TextStyle(
                        color: _request!.status == 'open'
                            ? Colors.green.shade700
                            : _request!.status == 'taken'
                                ? Colors.orange.shade700
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _request!.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  // Files section (only visible if requester or helper)
                  if (isRequester || _request!.helperId != null) ...[
                    Text(
                      'Files',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<RequestFile>>(
                      stream: Provider.of<FileService>(context)
                          .watchFiles(widget.requestId),
                      builder: (context, snapshot) {
                        final files = snapshot.data ?? [];
                        
                        if (files.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              isRequester
                                  ? 'No files uploaded yet'
                                  : 'No files available',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                            ),
                          );
                        }

                        return Column(
                          children: files.map((file) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.attach_file),
                                title: Text(file.fileName),
                                subtitle: Text(
                                  '${file.getFormattedSize()} • ${_formatTime(file.createdAt)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () => _openFile(file),
                                      tooltip: 'Download file',
                                    ),
                                    if (isRequester)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _deleteFile(file.id),
                                        tooltip: 'Delete file',
                                      ),
                                  ],
                                ),
                                onTap: () => _openFile(file),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    if (isRequester) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isUploadingFile ? null : _uploadFile,
                        icon: _isUploadingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isUploadingFile ? 'Uploading...' : 'Upload File'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                  if (canVolunteer)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _volunteer,
                        icon: const Icon(Icons.handshake),
                        label: const Text('I Can Help'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  if (canComplete)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _completeRequest,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark as Completed'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  if (canChat) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(request: _request!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Open Private Chat'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Comments Section (public comments visible to all) - Collapsible
          const Divider(height: 1),
          InkWell(
            onTap: () {
              setState(() {
                _commentsExpanded = !_commentsExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Icon(
                    _commentsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _commentsExpanded ? 300 : 0,
            child: _commentsExpanded
                ? Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<Comment>>(
                          stream: Provider.of<CommentService>(context)
                              .watchComments(widget.requestId),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final comments = snapshot.data ?? [];

                            // Auto-scroll to bottom when new comments arrive
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_commentScrollController.hasClients &&
                                  comments.isNotEmpty) {
                                _commentScrollController.animateTo(
                                  _commentScrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });

                            return comments.isEmpty
                                ? Center(
                                    child: Text(
                                      'No comments yet.\nBe the first to comment!',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _commentScrollController,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: comments.length,
                                    itemBuilder: (context, index) {
                                      final comment = comments[index];
                                      final isMe = comment.userId == currentUserId;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 8,
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                            backgroundImage: comment.userAvatarUrl != null
                                                ? NetworkImage(comment.userAvatarUrl!)
                                                : null,
                                            child: comment.userAvatarUrl == null
                                                ? Text(
                                                    (comment.userName ?? 'U')
                                                        .trim()
                                                        .isNotEmpty
                                                        ? (comment.userName ?? 'U')
                                                            .trim()[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  comment.userName ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (isMe)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline,
                                                      size: 18),
                                                  color: Colors.red.shade300,
                                                  onPressed: () {
                                                    _deleteComment(comment.id);
                                                  },
                                                  tooltip: 'Delete comment',
                                                ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(comment.comment),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatTime(comment.createdAt),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                          isThreeLine: true,
                                        ),
                                      );
                                    },
                                  );
                          },
                        ),
                      ),
                      // Comment input (only for authenticated users)
                      if (currentUserId != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Add a comment...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addComment(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed:
                                    _isSendingComment ? null : _addComment,
                                icon: _isSendingComment
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
