import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class ApproveOwnersScreen extends ConsumerStatefulWidget {
  const ApproveOwnersScreen({super.key});
  @override
  ConsumerState<ApproveOwnersScreen> createState() => _ApproveOwnersScreenState();
}

class _ApproveOwnersScreenState extends ConsumerState<ApproveOwnersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<UserModel> _pendingOwners = [];
  List<UserModel> _approvedOwners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    final fs = FirestoreService();
    final pending = await fs.getPendingOwners();
    final approved = await fs.getApprovedOwners();
    if (mounted) setState(() { _pendingOwners = pending; _approvedOwners = approved; _loading = false; });
  }

  Future<void> _approveOwner(UserModel owner) async {
    final licenseNum = 'HODS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    try {
      await FirestoreService().approveOwner(owner.uid, licenseNum);
      await _loadOwners();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${owner.name} approved! License: $licenseNum'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _rejectOwner(UserModel owner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Owner', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to reject ${owner.name}\'s application?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirestoreService().rejectOwner(owner.uid);
        await _loadOwners();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${owner.name} application rejected'), backgroundColor: AppColors.error),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Owner Approvals', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Pending (${_pendingOwners.length})'),
            Tab(text: 'Approved (${_approvedOwners.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: [
              _buildOwnerList(_pendingOwners, isPending: true),
              _buildOwnerList(_approvedOwners, isPending: false),
            ]),
    );
  }

  Widget _buildOwnerList(List<UserModel> owners, {required bool isPending}) {
    if (owners.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPending ? Icons.check_circle : Icons.people_outline, size: 72, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(isPending ? 'No pending approvals' : 'No approved owners', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: owners.length,
      itemBuilder: (_, i) => _buildOwnerCard(owners[i], isPending: isPending),
    );
  }

  Widget _buildOwnerCard(UserModel owner, {required bool isPending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: AppColors.primary, backgroundImage: owner.profileImageUrl.isNotEmpty ? NetworkImage(owner.profileImageUrl) : null, child: owner.profileImageUrl.isEmpty ? Text(owner.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(owner.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(owner.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              if (owner.businessName != null) Text(owner.businessName!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
            ])),
            if (!isPending) const Icon(Icons.verified, color: AppColors.success, size: 24),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.credit_card, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('CNIC: ${owner.cnic ?? "N/A"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  if (!isPending && owner.licenseNumber.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(owner.licenseNumber, style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text('Hostel Address: ${owner.hostelAddress ?? "N/A"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
              if (isPending && owner.licenseNumber.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.file_present_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Hostel License: ${owner.licenseNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ],
              if (owner.documentUrl != null && owner.documentUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Verification Document:', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            InteractiveViewer(
                              maxScale: 4.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(owner.documentUrl!, fit: BoxFit.contain),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              owner.documentUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 28),
                                    SizedBox(height: 4),
                                    Text('Tap to expand document', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isPending) ...[
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _rejectOwner(owner), icon: const Icon(Icons.close, size: 16), label: const Text('Reject'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () => _approveOwner(owner), icon: const Icon(Icons.check, size: 16), label: const Text('Approve'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success))),
            ]),
          ),
        ],
      ]),
    );
  }
}
