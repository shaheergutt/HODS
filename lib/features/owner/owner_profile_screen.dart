import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class OwnerProfileScreen extends ConsumerStatefulWidget {
  const OwnerProfileScreen({super.key});
  @override
  ConsumerState<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends ConsumerState<OwnerProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  XFile? _pickedImage;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _businessCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _businessCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _businessCtrl.dispose();
    super.dispose();
  }

  void _startEditing(UserModel user) {
    _nameCtrl.text = user.name;
    _phoneCtrl.text = user.phone;
    _businessCtrl.text = user.businessName ?? '';
    setState(() => _editing = true);
  }

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final file = await p.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _save(UserModel user) async {
    setState(() => _saving = true);
    try {
      String imageUrl = user.profileImageUrl;
      if (_pickedImage != null) imageUrl = await StorageService().uploadProfileImageXFile(user.uid, _pickedImage!);
      await FirestoreService().updateUser(user.copyWith(name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), businessName: _businessCtrl.text.trim(), profileImageUrl: imageUrl));
      if (mounted) setState(() { _editing = false; _saving = false; });
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)); setState(() => _saving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(backgroundColor: AppColors.background);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('My Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/owner');
                }
              },
            ),
            actions: [if (!_editing) IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _startEditing(user))],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              GestureDetector(
                onTap: _editing ? _pickImage : null,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.primary,
                    backgroundImage: _pickedImage != null ? (kIsWeb ? NetworkImage(_pickedImage!.path) : FileImage(File(_pickedImage!.path))) as ImageProvider : (user.profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(user.profileImageUrl) : null),
                    child: (_pickedImage == null && user.profileImageUrl.isEmpty) ? Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)) : null,
                  ),
                  if (_editing) Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16))),
                ]),
              ),
              const SizedBox(height: 12),
              if (!_editing) ...[
                Text(user.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: const Text('Hostel Owner', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: user.isApproved ? AppColors.success.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: Text(user.isApproved ? 'Verified ✓' : 'Pending', style: TextStyle(color: user.isApproved ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w600))),
                ]),
              ],
              const SizedBox(height: 24),
              if (_editing) ...[
                CustomTextField(label: 'Full Name', controller: _nameCtrl, prefixIcon: Icons.person_outline),
                const SizedBox(height: 14),
                CustomTextField(label: 'Phone', controller: _phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                CustomTextField(label: 'Business Name', controller: _businessCtrl, prefixIcon: Icons.business_outlined),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _editing = false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: CustomButton(text: 'Save', onPressed: () => _save(user), isLoading: _saving)),
                ]),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    _infoRow(Icons.phone_outlined, 'Phone', user.phone.isNotEmpty ? user.phone : 'Not set'),
                    _infoRow(Icons.business_outlined, 'Business', user.businessName ?? 'Not set'),
                    _infoRow(Icons.credit_card, 'CNIC', user.cnic ?? 'Not set'),
                    if (user.licenseNumber.isNotEmpty) _infoRow(Icons.verified, 'License No.', user.licenseNumber),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { await AuthService().signOut(); if (context.mounted) context.go('/'); }, icon: const Icon(Icons.logout, color: AppColors.error), label: const Text('Sign Out', style: TextStyle(color: AppColors.error)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.error)))),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
