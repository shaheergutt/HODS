import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/facility_chip.dart';

class EditHostelScreen extends ConsumerStatefulWidget {
  final String hostelId;
  const EditHostelScreen({super.key, required this.hostelId});
  @override
  ConsumerState<EditHostelScreen> createState() => _EditHostelScreenState();
}

class _EditHostelScreenState extends ConsumerState<EditHostelScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _roomsCtrl = TextEditingController();
  final _availableCtrl = TextEditingController();
  final _dailyRateCtrl = TextEditingController();
  final _weeklyRateCtrl = TextEditingController();
  final _monthlyRateCtrl = TextEditingController();
  String _city = '';
  String _genderPolicy = 'Male';
  final Set<String> _selectedFacilities = {};
  final List<String> _hostelImages = [];
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;
  HostelModel? _hostel;

  List<String> _citiesList = const ['Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot'];
  List<String> _facilitiesList = const ['WiFi', 'AC', 'Meals', 'Laundry', 'Generator', 'CCTV', 'Study Room', 'Gym', 'Parking', 'Water Cooler', 'Attached Bathroom', 'Geyser'];

  @override
  void initState() {
    super.initState();
    _loadMetadata().then((_) => _loadHostel());
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
          }
          if (amenitiesFetched.isNotEmpty) {
            _facilitiesList = amenitiesFetched;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHostel() async {
    final h = await FirestoreService().getHostel(widget.hostelId);
    if (h != null && mounted) {
      _nameCtrl.text = h.name; _descCtrl.text = h.description;
      _locationCtrl.text = h.location; _priceCtrl.text = h.pricePerMonth.toString();
      _roomsCtrl.text = h.totalRooms.toString(); _availableCtrl.text = h.availableRooms.toString();
      _dailyRateCtrl.text = h.dailyRate?.toString() ?? '';
      _weeklyRateCtrl.text = h.weeklyRate?.toString() ?? '';
      _monthlyRateCtrl.text = h.monthlyRate?.toString() ?? '';
      setState(() {
        _hostel = h;
        _city = h.city;
        _genderPolicy = h.genderPolicy;
        _selectedFacilities.addAll(h.facilities);
        _hostelImages.addAll(h.imageUrls);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose(); _priceCtrl.dispose(); _roomsCtrl.dispose(); _availableCtrl.dispose();
    _dailyRateCtrl.dispose(); _weeklyRateCtrl.dispose(); _monthlyRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNewImage() async {
    if (_hostel == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _uploadingImage = true);
    try {
      final storage = StorageService();
      final url = await storage.uploadHostelImageXFile(_hostel!.id, file);
      setState(() {
        _hostelImages.add(url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _deleteImageAtIndex(int index) async {
    if (_hostel == null) return;
    final url = _hostelImages[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Image', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this image?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _uploadingImage = true);
    try {
      final storage = StorageService();
      await storage.deleteFile(url);
      setState(() {
        _hostelImages.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image deleted successfully!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting image: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _replaceImageAtIndex(int index) async {
    if (_hostel == null) return;
    final oldUrl = _hostelImages[index];
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _uploadingImage = true);
    try {
      final supabaseStorage = SupabaseStorageService();
      final url = await supabaseStorage.replaceImage(File(file.path), oldUrl);
      if (url == null) throw Exception('Failed to replace image');

      setState(() {
        _hostelImages[index] = url;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image replaced successfully!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error replacing image: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (_hostel == null) return;
    setState(() => _saving = true);
    try {
      await FirestoreService().updateHostel(_hostel!.copyWith(
        name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(), city: _city,
        pricePerMonth: double.parse(_priceCtrl.text.trim()),
        totalRooms: int.parse(_roomsCtrl.text.trim()),
        availableRooms: int.parse(_availableCtrl.text.trim()),
        genderPolicy: _genderPolicy, facilities: _selectedFacilities.toList(),
        imageUrls: _hostelImages,
        dailyRate: _dailyRateCtrl.text.isNotEmpty ? double.parse(_dailyRateCtrl.text.trim()) : null,
        weeklyRate: _weeklyRateCtrl.text.isNotEmpty ? double.parse(_weeklyRateCtrl.text.trim()) : null,
        monthlyRate: _monthlyRateCtrl.text.isNotEmpty ? double.parse(_monthlyRateCtrl.text.trim()) : null,
      ));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hostel updated!'), backgroundColor: AppColors.success)); context.pop(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Edit Hostel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CustomTextField(label: 'Hostel Name', controller: _nameCtrl, prefixIcon: Icons.home_work_outlined),
          const SizedBox(height: 14),
          CustomTextField(label: 'Description', controller: _descCtrl, prefixIcon: Icons.description_outlined, maxLines: 3),
          const SizedBox(height: 14),
          CustomTextField(label: 'Address / Location', controller: _locationCtrl, prefixIcon: Icons.location_on_outlined),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _city.isEmpty ? _citiesList.first : _city,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: 'City', prefixIcon: const Icon(Icons.location_city), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border))),
            items: _citiesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _city = v ?? ''),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: CustomTextField(label: 'Price/Month (PKR)', controller: _priceCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: CustomTextField(label: 'Daily Rate (Optional)', controller: _dailyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: CustomTextField(label: 'Weekly Rate (Optional)', controller: _weeklyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: CustomTextField(label: 'Monthly Rate (Optional)', controller: _monthlyRateCtrl, prefixIcon: Icons.currency_rupee, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: CustomTextField(label: 'Total Rooms', controller: _roomsCtrl, prefixIcon: Icons.bed_outlined, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: CustomTextField(label: 'Available Rooms', controller: _availableCtrl, prefixIcon: Icons.meeting_room_outlined, keyboardType: TextInputType.number)),
          ]),
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
                child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hostel Gallery', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: _uploadingImage ? null : _addNewImage,
                icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                tooltip: 'Add new image',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_uploadingImage)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hostelImages.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('No images in gallery. Add one to display.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _hostelImages.length,
                itemBuilder: (ctx, i) => Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(_hostelImages[i], fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteImageAtIndex(i),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.delete, size: 14, color: Colors.redAccent),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _replaceImageAtIndex(i),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.cached, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          CustomButton(text: 'Save Changes', onPressed: _save, isLoading: _saving, icon: Icons.save_outlined),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
