import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/roommate_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/roommate_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class RoommateSetupScreen extends ConsumerStatefulWidget {
  const RoommateSetupScreen({super.key});
  @override
  ConsumerState<RoommateSetupScreen> createState() => _RoommateSetupScreenState();
}

class _RoommateSetupScreenState extends ConsumerState<RoommateSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roommateService = RoommateService();

  final _ageCtrl = TextEditingController();
  final _sleepCtrl = TextEditingController();
  final _wakeCtrl = TextEditingController();
  int _studyHours = 4;
  bool _smoking = false;
  bool _gaming = false;
  String _cleanliness = 'medium';
  String _personality = 'ambivert';
  final List<String> _interests = [];

  bool _saving = false;

  static const List<String> _allInterests = ['Coding', 'Gaming', 'Music', 'Reading', 'Sports', 'Cooking', 'Traveling', 'Anime', 'Fitness', 'Movies', 'Art', 'Photography'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _sleepCtrl.dispose();
    _wakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final p = await _roommateService.getProfile(user.uid);
    if (p != null) {
      _ageCtrl.text = p.age.toString();
      _sleepCtrl.text = p.sleepTime;
      _wakeCtrl.text = p.wakeTime;
      setState(() {
        _studyHours = p.studyHours;
        _smoking = p.smokingHabit;
        _gaming = p.gamingHabit;
        _cleanliness = p.cleanlinessLevel;
        _personality = p.personalityType;
        _interests.addAll(p.interests);
      });
    } else {
      _ageCtrl.text = '20';
      _sleepCtrl.text = '23:00';
      _wakeCtrl.text = '07:00';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    final profile = RoommateProfileModel(
      userId: user.uid,
      userName: user.name,
      userEmail: user.email,
      profileImageUrl: user.profileImageUrl,
      age: int.parse(_ageCtrl.text.trim()),
      gender: user.preferredGender, // match student gender preference
      sleepTime: _sleepCtrl.text.trim(),
      wakeTime: _wakeCtrl.text.trim(),
      studyHours: _studyHours,
      smokingHabit: _smoking,
      gamingHabit: _gaming,
      cleanlinessLevel: _cleanliness,
      personalityType: _personality,
      interests: _interests,
      university: user.university ?? '',
      budgetMin: user.budgetMin,
      budgetMax: user.budgetMax,
    );

    try {
      await _roommateService.saveProfile(profile);
      _showSnack('Roommate profile saved successfully!', AppColors.success);
      if (mounted) context.push('/student/roommate-matching');
    } catch (e) {
      _showSnack('Error saving profile: $e', AppColors.error);
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Roommate Match Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Roommate Compatibility Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Configure your daily habits so compatible roommates can discover you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            CustomTextField(
              label: 'Your Age',
              controller: _ageCtrl,
              prefixIcon: Icons.calendar_month,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: CustomTextField(
                  label: 'Sleep Time (HH:MM)',
                  controller: _sleepCtrl,
                  prefixIcon: Icons.nights_stay_outlined,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  label: 'Wake Time (HH:MM)',
                  controller: _wakeCtrl,
                  prefixIcon: Icons.wb_sunny_outlined,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Text('Daily Study Time: $_studyHours hours', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Slider(
              value: _studyHours.toDouble(),
              min: 1, max: 16, divisions: 15,
              activeColor: AppColors.primary, inactiveColor: AppColors.border,
              onChanged: (v) => setState(() => _studyHours = v.toInt()),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Do you smoke?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Switch(value: _smoking, onChanged: (v) => setState(() => _smoking = v), activeThumbColor: AppColors.primary),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Are you a gamer?', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Switch(value: _gaming, onChanged: (v) => setState(() => _gaming = v), activeThumbColor: AppColors.primary),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _cleanliness,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Cleanliness Level',
                prefixIcon: const Icon(Icons.cleaning_services),
                filled: true, fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Basic / Casual Cleanliness')),
                DropdownMenuItem(value: 'medium', child: Text('Moderate / Standard Cleanliness')),
                DropdownMenuItem(value: 'high', child: Text('Strict / High Cleanliness')),
              ],
              onChanged: (v) => setState(() => _cleanliness = v ?? 'medium'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _personality,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Personality Type',
                prefixIcon: const Icon(Icons.psychology),
                filled: true, fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
              items: const [
                DropdownMenuItem(value: 'introvert', child: Text('Introverted (Quiet, focus-driven)')),
                DropdownMenuItem(value: 'extrovert', child: Text('Extroverted (Social, outgoing)')),
                DropdownMenuItem(value: 'ambivert', child: Text('Ambivert (Balanced mixed traits)')),
              ],
              onChanged: (v) => setState(() => _personality = v ?? 'ambivert'),
            ),
            const SizedBox(height: 20),
            const Text('Hobbies & Hobbies Interests', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _allInterests.map((interest) {
                final sel = _interests.contains(interest);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) {
                      _interests.remove(interest);
                    } else {
                      _interests.add(interest);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: sel ? AppColors.primaryGradient : null,
                      color: sel ? null : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            CustomButton(text: 'Save and Search Roommates', onPressed: _save, isLoading: _saving, icon: Icons.people),
          ]),
        ),
      ),
    );
  }
}
