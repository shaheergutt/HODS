import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/room_model.dart';
import '../../services/firestore_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class AddEditRoomScreen extends StatefulWidget {
  final String hostelId;
  final String? roomId;
  const AddEditRoomScreen({super.key, required this.hostelId, this.roomId});

  @override
  State<AddEditRoomScreen> createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends State<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _db = FirestoreService();

  final _roomNumberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  
  String _roomType = 'single';
  int _occupiedBeds = 0;

  bool _loading = false;
  bool _saving = false;

  final List<String> _roomTypes = ['single', 'double', 'triple', 'quad', 'dormitory'];
  final List<String> _amenities = [];
  List<String> _allAmenities = const ['AC', 'Heater', 'Attached Bath', 'Wi-Fi', 'Study Table', 'Balcony', 'Cleaning Service'];

  // Room Image fields
  final List<XFile> _pickedImages = [];
  final List<String> _existingImages = [];
  bool _uploadingImages = false;

  @override
  void initState() {
    super.initState();
    _loadAmenities().then((_) {
      if (widget.roomId != null) {
        _loadRoom();
      }
    });
  }

  Future<void> _loadAmenities() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('amenities').get();
      final list = snap.docs.map((d) => d.data()['name'].toString()).toList();
      if (list.isNotEmpty && mounted) {
        setState(() {
          _allAmenities = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRoom() async {
    setState(() => _loading = true);
    try {
      final room = await _db.getRoom(widget.roomId!);
      if (room != null && mounted) {
        _roomNumberCtrl.text = room.roomNumber;
        _capacityCtrl.text = room.capacity.toString();
        _priceCtrl.text = room.price.toStringAsFixed(0);
        _descriptionCtrl.text = room.description;
        setState(() {
          _roomType = room.roomType.toLowerCase();
          _occupiedBeds = room.occupiedBeds;
          _existingImages.addAll(room.roomImages);
          _amenities.addAll(room.amenities);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading room: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _roomNumberCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 70);
    if (files.isNotEmpty) {
      setState(() => _pickedImages.addAll(files));
    }
  }

  Future<void> _deleteExistingImage(int index) async {
    final url = _existingImages[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Image', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this room image from storage?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _uploadingImages = true);
    try {
      final storage = SupabaseStorageService();
      await storage.deleteImage(url);
      setState(() {
        _existingImages.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room image deleted!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  Future<void> _replaceExistingImage(int index) async {
    final oldUrl = _existingImages[index];
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;

    setState(() => _uploadingImages = true);
    try {
      final storage = SupabaseStorageService();
      final url = await storage.replaceImage(File(file.path), oldUrl);
      if (url == null) throw Exception('Failed to replace image');

      setState(() {
        _existingImages[index] = url;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room image replaced!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error replacing image: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final capacity = int.parse(_capacityCtrl.text.trim());
      final price = double.parse(_priceCtrl.text.trim());

      final roomId = widget.roomId ?? const Uuid().v4();
      final List<String> uploadedUrls = List<String>.from(_existingImages);

      // Upload newly picked images to Supabase Storage
      if (_pickedImages.isNotEmpty) {
        final storage = SupabaseStorageService();
        for (final img in _pickedImages) {
          final id = const Uuid().v4();
          final path = 'rooms/$roomId/$id.jpg';
          final url = await storage.uploadImage(File(img.path), customPath: path);
          if (url != null) {
            uploadedUrls.add(url);
          }
        }
      }

      int finalOccupied = widget.roomId == null ? 0 : _occupiedBeds;
      if (finalOccupied > capacity) finalOccupied = capacity;
      final finalAvailable = capacity - finalOccupied;

      final room = RoomModel(
        roomId: roomId,
        hostelId: widget.hostelId,
        roomNumber: _roomNumberCtrl.text.trim(),
        roomType: _roomType.toLowerCase(),
        capacity: capacity,
        availableBeds: finalAvailable,
        occupiedBeds: finalOccupied,
        price: price,
        isActive: true,
        roomImages: uploadedUrls,
        description: _descriptionCtrl.text.trim(),
        amenities: _amenities,
      );

      if (widget.roomId == null) {
        await _db.createRoom(room);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room created successfully!'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      } else {
        await _db.updateRoom(room);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room updated successfully!'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving room: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.roomId != null;

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(isEdit ? 'Edit Room' : 'Add Room', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                label: 'Room Name / Identifier (e.g. 101, Room A-1)',
                controller: _roomNumberCtrl,
                prefixIcon: Icons.door_front_door_outlined,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _roomType,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Room Type',
                  prefixIcon: const Icon(Icons.category_outlined, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _roomType = v ?? 'single'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Bed Capacity (Total Beds)',
                controller: _capacityCtrl,
                prefixIcon: Icons.bed_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) return 'Must be a positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Price per Bed (PKR / month)',
                controller: _priceCtrl,
                prefixIcon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return 'Must be a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Room Description / Details',
                controller: _descriptionCtrl,
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              const Text('Room Amenities', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allAmenities.map((amenity) {
                  final hasAmenity = _amenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: hasAmenity,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primaryLight,
                    labelStyle: TextStyle(color: hasAmenity ? AppColors.primaryLight : AppColors.textSecondary, fontSize: 12),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _amenities.add(amenity);
                        } else {
                          _amenities.remove(amenity);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Room Images', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: _uploadingImages ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate, color: AppColors.primary),
                    tooltip: 'Add images',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_uploadingImages)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // Existing Images Gallery
              if (_existingImages.isNotEmpty) ...[
                const Text('Existing Images:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImages.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(_existingImages[i], fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteExistingImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.delete, size: 12, color: Colors.redAccent),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _replaceExistingImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.cached, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Newly Picked Images
              if (_pickedImages.isNotEmpty) ...[
                const Text('New Images to Upload:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(File(_pickedImages[i].path), fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedImages.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),
              CustomButton(
                text: isEdit ? 'Save Changes' : 'Create Room',
                onPressed: _submit,
                isLoading: _saving,
                icon: Icons.save_outlined,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
