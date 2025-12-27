import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/request_file.dart';

/// Service for managing file uploads for requests
class FileService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'request-files';

  /// Upload a file for a request (only requester can upload)
  Future<RequestFile> uploadFile(String requestId, PlatformFile file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Verify user is the requester
    final requestResponse = await _supabase
        .from('requests')
        .select('requester_id')
        .eq('id', requestId)
        .single();

    if (requestResponse['requester_id'] != user.id) {
      throw Exception('Only the requester can upload files');
    }

    // Generate unique file path
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileExtension = file.extension ?? '';
    final fileName = '${requestId}_$timestamp${fileExtension.isNotEmpty ? '.$fileExtension' : ''}';
    final filePath = '$requestId/$fileName';

    // Upload file to storage
    final fileBytes = file.bytes;
    if (fileBytes == null) {
      throw Exception('File bytes are null');
    }

    await _supabase.storage.from(_bucketName).uploadBinary(
      filePath,
      fileBytes,
      fileOptions: FileOptions(
        contentType: file.extension,
        upsert: false,
      ),
    );

    // Save file metadata to database
    final response = await _supabase
        .from('request_files')
        .insert({
          'request_id': requestId,
          'uploaded_by': user.id,
          'file_name': file.name,
          'file_path': filePath,
          'file_size': file.size,
          'mime_type': file.extension,
        })
        .select()
        .single();

    return RequestFile.fromJson(response);
  }

  /// Get all files for a request
  Future<List<RequestFile>> getRequestFiles(String requestId) async {
    final response = await _supabase
        .from('request_files')
        .select('*')
        .eq('request_id', requestId)
        .order('created_at', ascending: false);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    return rows.map((json) => RequestFile.fromJson(json)).toList();
  }

  /// Get download URL for a file
  String getFileUrl(String filePath) {
    return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }

  /// Delete a file (only requester can delete)
  Future<void> deleteFile(String fileId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Get file info
    final fileResponse = await _supabase
        .from('request_files')
        .select('request_id, file_path, uploaded_by')
        .eq('id', fileId)
        .single();

    if (fileResponse['uploaded_by'] != user.id) {
      throw Exception('Only the requester can delete files');
    }

    // Delete from storage
    await _supabase.storage.from(_bucketName).remove([fileResponse['file_path']]);

    // Delete from database
    await _supabase.from('request_files').delete().eq('id', fileId);
  }

  /// Watch files for a request in real-time
  Stream<List<RequestFile>> watchFiles(String requestId) {
    return _supabase
        .from('request_files')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at', ascending: false)
        .map((data) {
          final rows = data
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          return rows.map((json) => RequestFile.fromJson(json)).toList();
        });
  }
}

