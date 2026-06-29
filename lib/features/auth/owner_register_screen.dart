import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class OwnerRegisterScreen extends ConsumerStatefulWidget {
  const OwnerRegisterScreen({super.key});
  @override
  ConsumerState<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends ConsumerState<OwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  XFile? _documentFile;

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) {
      setState(() => _documentFile = file);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    _cnicCtrl.dispose();
    _addressCtrl.dispose();
    _licenseCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documentFile == null) {
      setState(() => _error = 'Please upload a verification document.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final storage = SupabaseStorageService();
      final File file = File(_documentFile!.path);
      final id = const Uuid().v4();
      final path = 'owner-documents/$id.jpg';
      final documentUrl = await storage.uploadImage(file, customPath: path);

      if (documentUrl == null) {
        throw Exception('Failed to upload verification document.');
      }

      await ref.read(authServiceProvider).registerOwner(
        email: _emailCtrl.text.trim(), password: _passCtrl.text,
        name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
        businessName: _businessCtrl.text.trim(), cnic: _cnicCtrl.text.trim(),
        hostelAddress: _addressCtrl.text.trim(), licenseNumber: _licenseCtrl.text.trim(),
        documentUrl: documentUrl,
      );
      if (mounted) context.go('/owner');
    } catch (e) {
      setState(() {
        _error = e.toString().contains('email-already-in-use')
            ? 'This email is already registered.' : e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/role-select'),
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18)),
              ),
              const SizedBox(width: 16),
              const Text('Owner Registration',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.secondary, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Your account needs admin approval before listing hostels. You will be notified once approved.',
                style: TextStyle(color: AppColors.secondary, fontSize: 12))),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  const SizedBox(height: 8),
                  CustomTextField(label: AppStrings.fullName, prefixIcon: Icons.person_outline,
                    controller: _nameCtrl, textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
                  const SizedBox(height: 14),
                  CustomTextField(label: 'Business / Hostel Name', prefixIcon: Icons.business_outlined,
                    controller: _businessCtrl, textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
                  const SizedBox(height: 14),
                  CustomTextField(label: AppStrings.email, prefixIcon: Icons.email_outlined,
                    controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) { if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                      if (!v.contains('@')) return AppStrings.invalidEmail; return null; }),
                  const SizedBox(height: 14),
                  CustomTextField(label: AppStrings.phoneNumber, prefixIcon: Icons.phone_outlined,
                    controller: _phoneCtrl, keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
                  const SizedBox(height: 14),
                  const SizedBox(height: 14),
                  CustomTextField(label: 'CNIC Number (e.g. 42101-1234567-1)', prefixIcon: Icons.credit_card_outlined,
                    controller: _cnicCtrl, keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Verification Document (CNIC / Ownership Proof)*',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDocument,
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _documentFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.file(
                                      File(_documentFile!.path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _documentFile = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, size: 32, color: AppColors.primary),
                                SizedBox(height: 4),
                                Text(
                                  'Tap to upload document photo',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(label: 'Hostel Address', prefixIcon: Icons.location_on_outlined,
                    controller: _addressCtrl, textInputAction: TextInputAction.next,
                    validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
                  const SizedBox(height: 14),
                  CustomTextField(label: 'Hostel License (Optional)', prefixIcon: Icons.file_present_outlined,
                    controller: _licenseCtrl, textInputAction: TextInputAction.next),
                  const SizedBox(height: 14),
                  CustomTextField(label: AppStrings.password, prefixIcon: Icons.lock_outline,
                    controller: _passCtrl, isPassword: true, textInputAction: TextInputAction.next,
                    validator: (v) { if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                      if (v.length < 6) return AppStrings.passwordTooShort; return null; }),
                  const SizedBox(height: 14),
                  CustomTextField(label: AppStrings.confirmPassword, prefixIcon: Icons.lock_outline,
                    controller: _confirmPassCtrl, isPassword: true, textInputAction: TextInputAction.done,
                    validator: (v) { if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                      if (v != _passCtrl.text) return AppStrings.passwordMismatch; return null; }),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (_error != null)
                Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
              CustomButton(text: 'Create Owner Account', isLoading: _loading, onPressed: _register),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text(AppStrings.alreadyHaveAccount, style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(onTap: () => context.go('/login'),
                  child: const Text(AppStrings.signIn, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
