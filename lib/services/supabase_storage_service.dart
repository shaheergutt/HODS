import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // CHANGE THIS TO MATCH YOUR ACTUAL BUCKET NAME
  static const String _bucketName = 'hostel_images';

  final Uuid _uuid = const Uuid();

  /// Compress image to under 2 MB
  Future<File> compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes <= 2 * 1024 * 1024) {
        return file;
      }

      img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return file;
      }

      if (decoded.width > 1920) {
        decoded = img.copyResize(decoded, width: 1920);
      }

      int quality = 85;

      List<int> compressedBytes =
          img.encodeJpg(decoded, quality: quality);

      while (
          compressedBytes.length > 2 * 1024 * 1024 &&
          quality > 10) {
        quality -= 10;

        compressedBytes =
            img.encodeJpg(decoded, quality: quality);
      }

      final tempDir = Directory.systemTemp;

      final tempFile = File(
        '${tempDir.path}/compressed_${_uuid.v4()}.jpg',
      );

      await tempFile.writeAsBytes(compressedBytes);

      return tempFile;
    } catch (e) {
      print('Compression Error: $e');
      return file;
    }
  }

  /// Upload image
  Future<String?> uploadImage(
    File imageFile, {
    String? customPath,
  }) async {
    try {
      print('========== STARTING UPLOAD ==========');

      final compressedFile =
          await compressImage(imageFile);

      final String path =
          customPath ?? 'uploads/${_uuid.v4()}.jpg';

      print('Bucket Name: $_bucketName');
      print('Upload Path: $path');
      print('Original File: ${imageFile.path}');
      print('Compressed File: ${compressedFile.path}');
      print(
          'File Exists: ${await compressedFile.exists()}');
      print(
          'File Size: ${await compressedFile.length()} bytes');

      final response = await _supabase.storage
          .from(_bucketName)
          .upload(
            path,
            compressedFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      print('UPLOAD RESPONSE: $response');

      final imageUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(path);

      print('PUBLIC URL: $imageUrl');
      print('========== UPLOAD SUCCESS ==========');

      return imageUrl;
    } catch (e, stackTrace) {
      print('========== SUPABASE ERROR ==========');
      print(e);
      print(stackTrace);
      print('===================================');

      return null;
    }
  }

  /// Delete image
  Future<void> deleteImage(
    String filePathOrUrl,
  ) async {
    try {
      final path = _extractPath(filePathOrUrl);

      if (path == null) return;

      await _supabase.storage
          .from(_bucketName)
          .remove([path]);

      print('Deleted: $path');
    } catch (e) {
      print('Delete Error: $e');
    }
  }

  /// Replace image
  Future<String?> replaceImage(
    File newImage,
    String oldPathOrUrl,
  ) async {
    try {
      final oldPath =
          _extractPath(oldPathOrUrl);

      if (oldPath != null) {
        await deleteImage(oldPath);
      }

      final String newPath =
          'uploads/${_uuid.v4()}.jpg';

      return await uploadImage(
        newImage,
        customPath: newPath,
      );
    } catch (e) {
      print('Replace Error: $e');
      return null;
    }
  }

  /// Extract file path from URL
  String? _extractPath(String pathOrUrl) {
    try {
      if (pathOrUrl.startsWith('http')) {
        final uri = Uri.parse(pathOrUrl);

        final segments = uri.pathSegments;

        final bucketIndex =
            segments.indexOf(_bucketName);

        if (bucketIndex != -1 &&
            bucketIndex + 1 < segments.length) {
          return segments
              .sublist(bucketIndex + 1)
              .join('/');
        }
      }

      return pathOrUrl;
    } catch (e) {
      print('Extract Path Error: $e');
      return null;
    }
  }
}