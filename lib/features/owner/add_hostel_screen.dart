// ignore: avoid_web_libraries_in_flutter
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/facility_chip.dart';

class AddHostelScreen extends ConsumerStatefulWidget {
  const AddHostelScreen({super.key});
  @override
  ConsumerState<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends ConsumerState<AddHostelScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController();
  final _dailyRateCtrl = TextEditingController();
  final _weeklyRateCtrl = TextEditingController();
  final _monthlyRateCtrl = TextEditingController();

  String _city = 'Lahore';
  String _genderPolicy = 'Male';
  final Set<String> _selectedFacilities = {};
  final List<XFile> _images = [];
  bool _saving = false;

  List<String> _citiesList = ['Lahore'];
  List<String> _facilitiesList = [];
  bool _loadingMetadata = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final citiesSnap = await FirebaseFirestore.instance.collection('cities').get();
      final amenitiesSnap = await FirebaseFirestore.instance.collection('amenities').get();

      final citiesFetched = citiesSnap.docs.map((d) => d.data()['name'].toString()).toList();
      final amenitiesFetched = amenitiesSnap.docs.map((d) => d.data()['name'].toString()).toList();

      if (mounted) {
        setState(() {
          if (citiesFetched.isNotEmpty) {
            _citiesList = citiesFetched;
            _city = citiesFetched.contains('Lahore') ? 'Lahore' : citiesFetched.first;
          }
          if (amenitiesFetched.isNotEmpty) {
            _facilitiesList = amenitiesFetched;
          }
          _loadingMetadata = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _citiesList = ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot'];
          _facilitiesList = ['WiFi', 'AC', 'Meals', 'Laundry', 'Generator', 'CCTV', 'Study Room', 'Gym', 'Parking', 'Water Cooler', 'Attached Bathroom', 'Geyser'];
          _loadingMetadata = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose(); _priceCtrl.dispose(); _roomsCtrl.dispose();
    _dailyRateCtrl.dispose(); _weeklyRateCtrl.dispose(); _monthlyRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final p = ImagePicker();
    final files = await p.pickMultiImage(imageQuality: 70);
    if (files.isNotEmpty) setState(() => _images.addAll(files));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) { _showSnack('Please add at least one image', AppColors.error); return; }
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final hostelId = const Uuid().v4();
      final storage = StorageService();
      final imageUrls = <String>[];
      for (final img in _images) {
        final url = await storage.uploadHostelImageXFile(hostelId, img);
        imageUrls.add(url);
      }

      final hostel = HostelModel(
        id: hostelId, ownerId: user.uid, ownerName: user.name,
        name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(), city: _city,
        pricePerMonth: double.parse(_priceCtrl.text.trim()),
        totalRooms: int.parse(_roomsCtrl.text.trim()),
        availableRooms: int.parse(_roomsCtrl.text.trim()),
        facilities: _selectedFacilities.toList(),
        imageUrls: imageUrls, genderPolicy: _genderPolicy,
        isApproved: false, licenseNumber: '', rating: 0, reviewCount: 0,
        createdAt: DateTime.now(),
        dailyRate: _dailyRateCtrl.text.isNotEmpty ? double.parse(_dailyRateCtrl.text.trim()) : null,
        weeklyRate: _weeklyRateCtrl.text.isNotEmpty ? double.parse(_weeklyRateCtrl.text.trim()) : null,
        monthlyRate: _monthlyRateCtrl.text.isNotEmpty ? double.parse(_monthlyRateCtrl.text.trim()) : null,
        isActive: true,
      );
      await FirestoreService().createHostel(hostel);
      if (mounted) { _showSnack('Hostel submitted for approval!', AppColors.success); context.go('/owner'); }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Add Hostel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: IndexedStack(index: _step, children: [_buildStep1(), _buildStep2(), _buildStep3()]),
      ),
    );
  }

  Widget _buildStep1() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Basic Info', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      CustomTextField(label: 'Hostel Name', controller: _nameCtrl, prefixIcon: Icons.home_work_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
      const SizedBox(height: 14),
      CustomTextField(label: 'Description', controller: _descCtrl, prefixIcon: Icons.description_outlined, maxLines: 3, validator: (v) => v!.isEmpty ? 'Required' : null),
      const SizedBox(height: 14),
      CustomTextField(label: 'Address / Location', controller: _locationCtrl, prefixIcon: Icons.location_on_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: _city,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: 'City', prefixIcon: const Icon(Icons.location_city), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border))),
        items: _citiesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _city = v ?? 'Lahore'),
      ),
      const SizedBox(height: 24),
      CustomButton(text: 'Next: Pricing & Rooms', onPressed: () { if (_formKey.currentState!.validate()) setState(() => _step = 1); }, icon: Icons.arrow_forward),
    ]),
  );

  Widget _buildStep2() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pricing & Rooms', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      CustomTextField(label: 'Price per Month (PKR)', controller: _priceCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number, validator: (v) => (_step >= 1 && (v == null || v.isEmpty)) ? 'Required' : null),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: CustomTextField(label: 'Daily Rate (Optional)', controller: _dailyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: CustomTextField(label: 'Weekly Rate (Optional)', controller: _weeklyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 14),
      CustomTextField(label: 'Monthly Rate (Optional)', controller: _monthlyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number),
      const SizedBox(height: 14),
      CustomTextField(label: 'Total Rooms', controller: _roomsCtrl, prefixIcon: Icons.bed_outlined, keyboardType: TextInputType.number, validator: (v) => (_step >= 1 && (v == null || v.isEmpty)) ? 'Required' : null),
      const SizedBox(height: 14),
      const Text('Gender Policy', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: ['Male', 'Female', 'Both'].map((g) {
        final sel = _genderPolicy == g;
        return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
          onTap: () => setState(() => _genderPolicy = g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
            child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          ),
        ));
      }).toList()),
      const SizedBox(height: 24),
      const Text('Facilities', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _facilitiesList.map((f) {
        final sel = _selectedFacilities.contains(f);
        return FacilityChip(label: f, isSelected: sel, onTap: () => setState(() { if (sel) {
          _selectedFacilities.remove(f);
        } else {
          _selectedFacilities.add(f);
        } }));
      }).toList()),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Back'))),
        const SizedBox(width: 12),
        Expanded(child: CustomButton(text: 'Next: Photos', onPressed: () { if (_formKey.currentState!.validate()) setState(() => _step = 2); }, icon: Icons.arrow_forward)),
      ]),
    ]),
  );

  Widget _buildStep3() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Photos', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      const Text('Add photos to attract more students', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 120, width: double.infinity,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), style: BorderStyle.solid, width: 2)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary),
            SizedBox(height: 8),
            Text('Tap to add photos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      if (_images.isNotEmpty) ...[
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            itemBuilder: (_, i) => Stack(children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 100, height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: (kIsWeb ? NetworkImage(_images[i].path) : FileImage(File(_images[i].path))) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(top: 4, right: 12, child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(i)),
                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
              )),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.info.withValues(alpha: 0.3))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Your hostel will be reviewed by our admin team before going live. This takes 1-2 business days.', style: TextStyle(color: AppColors.info, fontSize: 12))),
        ]),
      ),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Back'))),
        const SizedBox(width: 12),
        Expanded(child: CustomButton(text: 'Submit for Approval', onPressed: _submit, isLoading: _saving, icon: Icons.check_circle_outline)),
      ]),
      const SizedBox(height: 32),
    ]),
  );
}
