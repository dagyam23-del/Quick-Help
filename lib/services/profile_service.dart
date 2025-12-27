import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Profile?> getProfile(String userId) async {
    try {
      final response =
          await _supabase.from('profiles').select('*').eq('id', userId).single();
      return Profile.fromJson(Map<String, dynamic>.from(response));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Profile>> getProfilesByIds(Iterable<String> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', ids);
      final list = (response as List)
          .map((row) => Profile.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return {for (final p in list) p.id: p};
    } catch (_) {
      return {};
    }
  }

  Future<void> upsertMyProfile({String? name, String? avatarUrl}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final payload = <String, dynamic>{
      'id': user.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) payload['name'] = name;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

    await _supabase.from('profiles').upsert(payload);
  }

  /// Upload avatar to the `avatar` storage bucket and return the public URL.
  Future<String> uploadMyAvatar(XFile file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final Uint8List bytes = await file.readAsBytes();
    final ext = _fileExtension(file.name);
    final objectPath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage.from('avatar').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFromExt(ext),
            upsert: true,
          ),
        );

    return _supabase.storage.from('avatar').getPublicUrl(objectPath);
  }

  static String _fileExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot == -1 || dot == filename.length - 1) return 'png';
    return filename.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }
}


