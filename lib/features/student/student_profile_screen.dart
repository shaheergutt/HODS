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

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  XFile? _pickedImage;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  String _city = '';
  
  // Advanced recommendation preference states
  String _cleanliness = 'any';
  String _noise = 'any';
  String _sharing = 'any';
  String _diet = 'any';
  String _transport = 'any';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEditing(UserModel user) {
    _nameCtrl.text = user.name;
    _phoneCtrl.text = user.phone;
    _city = user.preferredCity ?? '';
    _cleanliness = user.cleanlinessPref;
    _noise = user.noisePref;
    _sharing = user.sharingPref;
    _diet = user.dietPref;
    _transport = user.transportPref;
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
      if (_pickedImage != null) {
        imageUrl = await StorageService().uploadProfileImageXFile(user.uid, _pickedImage!);
      }
      await FirestoreService().updateUser(user.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        preferredCity: _city,
        profileImageUrl: imageUrl,
        cleanlinessPref: _cleanliness,
        noisePref: _noise,
        sharingPref: _sharing,
        dietPref: _diet,
        transportPref: _transport,
      ));
      if (mounted) setState(() { _editing = false; _saving = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Error: $e'))),
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
                  context.go('/student');
                }
              },
            ),
            actions: [
              if (!_editing)
                IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _startEditing(user)),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Avatar
              GestureDetector(
                onTap: _editing ? _pickImage : null,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.primary,
                    backgroundImage: _pickedImage != null
                        ? (kIsWeb ? NetworkImage(_pickedImage!.path) : FileImage(File(_pickedImage!.path))) as ImageProvider
                        : (user.profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(user.profileImageUrl) : null),
                    child: (_pickedImage == null && user.profileImageUrl.isEmpty)
                        ? Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  if (_editing)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              if (!_editing) ...[
                Text(user.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Student', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 24),
              if (_editing) ...[
                CustomTextField(label: 'Full Name', controller: _nameCtrl, prefixIcon: Icons.person_outline),
                const SizedBox(height: 14),
                CustomTextField(label: 'Phone', controller: _phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                _buildCityDropdown(),
                const SizedBox(height: 24),
                
                // Advanced Recommendation Preferences Card Title
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recommendation Matching Preferences', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                
                _buildPreferenceDropdown(
                  label: 'Cleanliness Requirement',
                  icon: Icons.cleaning_services_outlined,
                  value: _cleanliness,
                  items: {'high': 'Strict Cleanliness preferred', 'medium': 'Moderate Cleanliness', 'any': 'No strict preference'},
                  onChanged: (v) => setState(() => _cleanliness = v ?? 'any'),
                ),
                const SizedBox(height: 14),
                
                _buildPreferenceDropdown(
                  label: 'Noise Level Tolerance',
                  icon: Icons.volume_mute_outlined,
                  value: _noise,
                  items: {'quiet': 'Quiet Study-focused Environment', 'any': 'No preference'},
                  onChanged: (v) => setState(() => _noise = v ?? 'any'),
                ),
                const SizedBox(height: 14),
                
                _buildPreferenceDropdown(
                  label: 'Room Sharing Pref',
                  icon: Icons.bed_outlined,
                  value: _sharing,
                  items: {'single': 'Single Room only', 'shared': 'Shared Room preferred', 'any': 'No preference'},
                  onChanged: (v) => setState(() => _sharing = v ?? 'any'),
                ),
                const SizedBox(height: 14),
                
                _buildPreferenceDropdown(
                  label: 'Dietary Mess Pref',
                  icon: Icons.restaurant_outlined,
                  value: _diet,
                  items: {'veg': 'Vegetarian only', 'non-veg': 'Non-Vegetarian/Both', 'any': 'No mess preference'},
                  onChanged: (v) => setState(() => _diet = v ?? 'any'),
                ),
                const SizedBox(height: 14),
                
                _buildPreferenceDropdown(
                  label: 'Transportation / Transit Needs',
                  icon: Icons.directions_bus_outlined,
                  value: _transport,
                  items: {'parking': 'Need active vehicle parking space', 'walking': 'Walking distance to university', 'shuttle': 'Requires shuttle / metro access', 'any': 'No preference'},
                  onChanged: (v) => setState(() => _transport = v ?? 'any'),
                ),
                const SizedBox(height: 24),
                
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: CustomButton(text: 'Save Details', onPressed: () => _save(user), isLoading: _saving)),
                ]),
              ] else ...[
                _buildInfoCard([
                  _infoRow(Icons.phone_outlined, 'Phone', user.phone.isNotEmpty ? user.phone : 'Not set'),
                  _infoRow(Icons.location_city, 'Preferred City', user.preferredCity ?? 'Not set'),
                  _infoRow(Icons.school_outlined, 'University', user.university ?? 'Not set'),
                ]),
                const SizedBox(height: 18),
                
                // Advanced Recommendation Preferences Card View
                _buildAdvancedPreferencesCard(user),
                const SizedBox(height: 18),

                if (user.preferredFacilities.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Preferred Facilities', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: user.preferredFacilities.map((f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                    child: Text(f, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  )).toList()),
                  const SizedBox(height: 24),
                ],
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) context.go('/');
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.error)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildCityDropdown() {
    const cities = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta'];
    return DropdownButtonFormField<String>(
      initialValue: _city.isEmpty ? null : _city,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Preferred City',
        prefixIcon: const Icon(Icons.location_city, color: AppColors.textSecondary),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _city = v ?? ''),
    );
  }

  Widget _buildPreferenceDropdown({
    required String label,
    required IconData icon,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildAdvancedPreferencesCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.insights, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Recommendation Profile', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        const Text(
          'These custom metrics allow the HODS matching engine to dynamically rate hostels based on your lifestyle requirements:',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        _preferenceChipRow(
          Icons.cleaning_services_outlined,
          'Cleanliness:',
          user.cleanlinessPref == 'high' ? 'Strict Cleanliness' : (user.cleanlinessPref == 'medium' ? 'Moderate' : 'No strict pref'),
          user.cleanlinessPref != 'any' ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(height: 10),
        _preferenceChipRow(
          Icons.volume_mute_outlined,
          'Noise Level:',
          user.noisePref == 'quiet' ? 'Quiet/Study Focus' : 'No preference',
          user.noisePref != 'any' ? Colors.teal : AppColors.textHint,
        ),
        const SizedBox(height: 10),
        _preferenceChipRow(
          Icons.bed_outlined,
          'Room Sharing:',
          user.sharingPref == 'single' ? 'Single Room Only' : (user.sharingPref == 'shared' ? 'Shared Space' : 'No preference'),
          user.sharingPref != 'any' ? Colors.orange : AppColors.textHint,
        ),
        const SizedBox(height: 10),
        _preferenceChipRow(
          Icons.restaurant_outlined,
          'Diet/Mess:',
          user.dietPref == 'veg' ? 'Vegetarian Only' : (user.dietPref == 'non-veg' ? 'Non-Veg / Mixed' : 'No preference'),
          user.dietPref != 'any' ? Colors.green : AppColors.textHint,
        ),
        const SizedBox(height: 10),
        _preferenceChipRow(
          Icons.directions_bus_outlined,
          'Transit Needs:',
          user.transportPref == 'parking' ? 'Parking Required' : (user.transportPref == 'walking' ? 'Walking Distance' : (user.transportPref == 'shuttle' ? 'Shuttle/Metro Access' : 'No preference')),
          user.transportPref != 'any' ? Colors.purple : AppColors.textHint,
        ),
      ]),
    );
  }

  Widget _preferenceChipRow(IconData icon, String title, String value, Color color) {
    final active = color != AppColors.textHint;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Text(
          value,
          style: TextStyle(color: active ? color : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    ]);
  }

  Widget _buildInfoCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: children),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}
