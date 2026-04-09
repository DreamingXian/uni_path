import 'dart:io';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

class FileService {
  final _supabase = Supabase.instance.client;

  /// Uploads a file to a specific bucket and returns the Public URL
  Future<String?> uploadImage({
    required File file,
    required String bucket,
    required String fileName,
  }) async {
    try {
      // 1. Perform the upload
      await _supabase.storage.from(bucket).upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // 2. Get the public URL
      final String publicUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);

      log('File uploaded to $bucket. URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      log('Error uploading file: $e');
      return null;
    }
  }
}