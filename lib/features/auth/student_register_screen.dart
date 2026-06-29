import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class StudentRegisterScreen extends ConsumerStatefulWidget {
  const StudentRegisterScreen({super.key});
  @override
  ConsumerState<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends ConsumerState<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _uniCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _selectedCity = AppStrings.cities.first;
  final List<String> _selectedFacilities = [];
  String _selectedGender = 'mixed';
  int _budgetMin = 5000, _budgetMax = 30000;
  bool _loading = false;
  String? _error;
  int _step = 0;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).registerStudent(
        email: _emailCtrl.text.trim(), password: _passCtrl.text,
        name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
        university: _uniCtrl.text.trim(), preferredCity: _selectedCity,
        preferredFacilities: _selectedFacilities, preferredGender: _selectedGender,
        budgetMin: _budgetMin, budgetMax: _budgetMax,
      );
      if (mounted) context.go('/student');
    } catch (e) {
      setState(() {
        _error = e.toString().contains('email-already-in-use')
            ? 'This email is already registered.' : AppStrings.somethingWentWrong;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _step == 0 ? context.go('/role-select') : setState(() => _step--),
                  child: Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Student Registration',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: (_step + 1) / 2,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 2),
                  Text('Step ${_step + 1} of 2',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(key: _formKey,
                  child: _step == 0 ? _buildStep1() : _buildStep2()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (_error != null)
                  Container(padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                CustomButton(
                  text: _step == 0 ? 'Next' : 'Create Account',
                  isLoading: _loading,
                  onPressed: _step == 0
                      ? () { if (_formKey.currentState!.validate()) setState(() => _step = 1); }
                      : _register,
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text(AppStrings.alreadyHaveAccount, style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(onTap: () => context.go('/login'),
                    child: const Text(AppStrings.signIn, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(children: [
      const SizedBox(height: 8),
      CustomTextField(label: AppStrings.fullName, prefixIcon: Icons.person_outline,
        controller: _nameCtrl, textInputAction: TextInputAction.next,
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
      CustomTextField(label: 'University / College', prefixIcon: Icons.school_outlined,
        controller: _uniCtrl, textInputAction: TextInputAction.next,
        validator: (v) => v == null || v.isEmpty ? AppStrings.fieldRequired : null),
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
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      const Text('Preferred City', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8,
        children: AppStrings.cities.map((city) {
          final sel = _selectedCity == city;
          return GestureDetector(onTap: () => setState(() => _selectedCity = city),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: sel ? AppColors.primaryGradient : null,
                color: sel ? null : AppColors.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
              child: Text(city, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary,
                fontSize: 13, fontWeight: FontWeight.w500))));
        }).toList()),
      const SizedBox(height: 20),
      const Text('Required Facilities', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8,
        children: AppStrings.facilityList.map((f) {
          final sel = _selectedFacilities.contains(f);
          return GestureDetector(onTap: () => setState(() { sel ? _selectedFacilities.remove(f) : _selectedFacilities.add(f); }),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(gradient: sel ? AppColors.primaryGradient : null,
                color: sel ? null : AppColors.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
              child: Text(f, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary,
                fontSize: 13, fontWeight: FontWeight.w500))));
        }).toList()),
      const SizedBox(height: 20),
      const Text('Gender Preference', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Row(children: ['male', 'female', 'mixed'].map((g) {
        final sel = _selectedGender == g;
        return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGender = g),
          child: Container(margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(gradient: sel ? AppColors.primaryGradient : null,
              color: sel ? null : AppColors.inputFill, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
            child: Text(g[0].toUpperCase() + g.substring(1), textAlign: TextAlign.center,
              style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary,
                fontSize: 13, fontWeight: FontWeight.w500)))));
      }).toList()),
      const SizedBox(height: 20),
      Text('Budget: PKR ${_fmtK(_budgetMin)} - ${_fmtK(_budgetMax)}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      RangeSlider(values: RangeValues(_budgetMin.toDouble(), _budgetMax.toDouble()),
        min: 3000, max: 80000, divisions: 77,
        activeColor: AppColors.primary, inactiveColor: AppColors.border,
        onChanged: (v) => setState(() { _budgetMin = v.start.toInt(); _budgetMax = v.end.toInt(); })),
      const SizedBox(height: 16),
    ]);
  }

  String _fmtK(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toString();
}
