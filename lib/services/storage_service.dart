import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'supabase_storage_service.dart';

class StorageService {
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  final _supabaseStorage = SupabaseStorageService();

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    return picked;
  }

  Future<List<XFile>> pickMultipleImages() async {
    return await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1024);
  }

  /// Upload an XFile (works on both web and mobile) to Supabase Storage
  Future<String> uploadHostelImageXFile(String hostelId, XFile file) async {
    final id = _uuid.v4();
    final path = 'hostels/$hostelId/$id.jpg';
    final imageFile = File(file.path);
    final url = await _supabaseStorage.uploadImage(imageFile, customPath: path);
    if (url == null) {
      throw Exception('Failed to upload hostel image to Supabase');
    }
    return url;
  }

  /// Upload profile image from XFile (works on both web and mobile) to Supabase Storage
  Future<String> uploadProfileImageXFile(String uid, XFile file) async {
    final path = 'profiles/$uid.jpg';
    final imageFile = File(file.path);
    final url = await _supabaseStorage.uploadImage(imageFile, customPath: path);
    if (url == null) {
      throw Exception('Failed to upload profile image to Supabase');
    }
    return url;
  }

  Future<List<String>> uploadHostelImages(String hostelId, List<XFile> files) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadHostelImageXFile(hostelId, file);
      urls.add(url);
    }
    return urls;
  }

  Future<void> deleteFile(String url) async {
    await _supabaseStorage.deleteImage(url);
  }
}
