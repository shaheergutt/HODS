import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hostel_provider.dart';
import '../../widgets/hostel_card.dart';
import '../../widgets/common/facility_chip.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCity = '';
  final Set<String> _selectedFacilities = {};
  double _maxPrice = 30000;
  String _selectedGender = '';
  String _sortBy = 'rating';

  static const List<String> _cities = [
    'All', 'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi',
    'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot',
  ];

  static const List<String> _facilities = [
    'WiFi', 'AC', 'Meals', 'Laundry', 'Generator', 'CCTV',
    'Study Room', 'Gym', 'Parking', 'Water Cooler',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HostelModel> _filterHostels(List<HostelModel> list) {
    // City filter (preferred city default if set and search query is empty)
    if (_query.isEmpty && _selectedCity.isEmpty) {
      final user = ref.read(currentUserProvider).value;
      if (user?.preferredCity != null) {
        list = list.where((h) => h.city.toLowerCase() == user!.preferredCity!.toLowerCase()).toList();
      }
    } else if (_selectedCity.isNotEmpty && _selectedCity != 'All') {
      list = list.where((h) => h.city.toLowerCase() == _selectedCity.toLowerCase()).toList();
    }

    // Query filter
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((h) => h.name.toLowerCase().contains(q) || h.city.toLowerCase().contains(q) || h.location.toLowerCase().contains(q)).toList();
    }

    // Gender filter
    if (_selectedGender.isNotEmpty) {
      list = list.where((h) => h.genderPolicy == _selectedGender).toList();
    }

    // Facilities filter
    if (_selectedFacilities.isNotEmpty) {
      list = list.where((h) => _selectedFacilities.every((f) => h.facilities.contains(f))).toList();
    }

    // Price filter
    list = list.where((h) => h.pricePerMonth <= _maxPrice).toList();

    // Sorting
    if (_sortBy == 'price_low' || _sortBy == 'price_asc') {
      list.sort((a, b) => a.pricePerMonth.compareTo(b.pricePerMonth));
    } else if (_sortBy == 'price_high' || _sortBy == 'price_desc') {
      list.sort((a, b) => b.pricePerMonth.compareTo(a.pricePerMonth));
    } else {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list.where((h) => h.isApproved).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hostelsAsync = ref.watch(allHostelsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Find Hostels',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.primary),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by city, name, or location...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _cities.length,
              itemBuilder: (ctx, i) {
                final city = _cities[i];
                final selected = _selectedCity == city || (city == 'All' && _selectedCity.isEmpty);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCity = city == 'All' ? '' : city),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(city,
                          style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: hostelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (hostels) {
                final filtered = _filterHostels(hostels);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('No hostels found',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Try adjusting your filters', style: TextStyle(color: AppColors.textSecondary)),
                    ]),
                  );
                }
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(children: [
                      Text('${filtered.length} hostels found',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => HostelCard(hostel: filtered[i], currentUser: user),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filters', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () { setState(() { _selectedFacilities.clear(); _maxPrice = 30000; _selectedGender = ''; _sortBy = 'rating'; }); Navigator.pop(ctx); }, child: const Text('Reset')),
            ]),
            const SizedBox(height: 16),
            const Text('Sort By', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'label': 'Top Rated', 'value': 'rating'},
                {'label': 'Price: Low to High', 'value': 'price_asc'},
                {'label': 'Price: High to Low', 'value': 'price_desc'},
              ].map((s) {
                final sel = _sortBy == s['value'];
                return GestureDetector(
                  onTap: () => setSheet(() => _sortBy = s['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(s['label']!, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Max Monthly Price', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            Text('PKR ${_maxPrice.toInt()}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Slider(value: _maxPrice, min: 3000, max: 50000, divisions: 47, activeColor: AppColors.primary, onChanged: (v) => setSheet(() => _maxPrice = v)),
            const SizedBox(height: 12),
            const Text('Gender Policy', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Male', 'Female', 'Both'].map((g) {
                final sel = _selectedGender == g;
                return GestureDetector(
                  onTap: () => setSheet(() => _selectedGender = sel ? '' : g),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Facilities', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _facilities.map((f) {
              final sel = _selectedFacilities.contains(f);
              return FacilityChip(label: f, isSelected: sel, onTap: () => setSheet(() { if (sel) {
                _selectedFacilities.remove(f);
              } else {
                _selectedFacilities.add(f);
              } }));
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () { setState(() {}); Navigator.pop(ctx); },
                child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        );
      }),
    );
  }
}
