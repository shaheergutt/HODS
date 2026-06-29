import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../services/firestore_service.dart';

class ManageHostelsScreen extends ConsumerStatefulWidget {
  const ManageHostelsScreen({super.key});
  @override
  ConsumerState<ManageHostelsScreen> createState() => _ManageHostelsScreenState();
}

class _ManageHostelsScreenState extends ConsumerState<ManageHostelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<HostelModel> _pendingHostels = [];
  List<HostelModel> _approvedHostels = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadHostels();
  }

  Future<void> _loadHostels() async {
    final fs = FirestoreService();
    try {
      final pending = await fs.getPendingHostels();
      final approved = await fs.getApprovedHostels();
      if (mounted) {
        setState(() {
          _pendingHostels = pending;
          _approvedHostels = approved;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hostels: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _approveHostel(HostelModel hostel) async {
    try {
      await FirestoreService().approveHostel(hostel.id);
      await _loadHostels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${hostel.name}" has been approved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _rejectHostel(HostelModel hostel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Hostel', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to reject and deactivate "${hostel.name}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirestoreService().rejectHostel(hostel.id);
        await _loadHostels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${hostel.name}" rejected and deactivated.'), backgroundColor: AppColors.error),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  List<HostelModel> _filter(List<HostelModel> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((h) => h.name.toLowerCase().contains(q) || h.ownerName.toLowerCase().contains(q) || h.city.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Manage Hostels', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search hostels by name, owner, or city...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(text: 'Pending (${_filter(_pendingHostels).length})'),
                Tab(text: 'Approved (${_filter(_approvedHostels).length})'),
              ],
            ),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _buildHostelList(_filter(_pendingHostels), isPending: true),
              _buildHostelList(_filter(_approvedHostels), isPending: false),
            ]),
    );
  }

  Widget _buildHostelList(List<HostelModel> hostels, {required bool isPending}) {
    if (hostels.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPending ? Icons.check_circle_outline : Icons.apartment, size: 72, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(isPending ? 'No pending hostel reviews' : 'No approved hostels', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hostels.length,
      itemBuilder: (_, i) => _buildHostelCard(hostels[i], isPending: isPending),
    );
  }

  Widget _buildHostelCard(HostelModel hostel, {required bool isPending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Image / Icon thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hostel.imageUrls.isNotEmpty
                  ? Image.network(hostel.imageUrls.first, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildIconThumbnail())
                  : _buildIconThumbnail(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hostel.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Owner: ${hostel.ownerName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 13),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${hostel.location}, ${hostel.city}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(hostel.genderPolicy, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text('PKR ${hostel.pricePerMonth.toStringAsFixed(0)}/mo', style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hostel.description.isNotEmpty) ...[
                Text(hostel.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: hostel.facilities.take(4).map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(6)),
                  child: Text(f, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                )).toList(),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (isPending) ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _rejectHostel(hostel),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _approveHostel(hostel),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              )),
            ] else ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _rejectHostel(hostel),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Deactivate / Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              )),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildIconThumbnail() {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.apartment, color: AppColors.primary, size: 28),
    );
  }
}
