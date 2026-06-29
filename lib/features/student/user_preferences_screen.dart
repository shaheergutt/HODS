import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../models/user_preferences_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class UserPreferencesScreen extends ConsumerStatefulWidget {
  const UserPreferencesScreen({super.key});
  @override
  ConsumerState<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends ConsumerState<UserPreferencesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _recsService = RecommendationService();

  final _budgetCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  bool _wifi = false;
  bool _ac = false;
  bool _mess = false;
  String _roomType = 'any';

  bool _saving = false;
  bool _loadingRecs = false;
  List<Map<String, dynamic>> _recommendations = [];
  final Map<String, String> _explanations = {}; // Cache AI explanations by hostelId
  final Map<String, bool> _loadingExplanations = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _budgetCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final prefs = await _recsService.getPreferences(user.uid);
    if (prefs != null) {
      _budgetCtrl.text = prefs.maxBudget.toInt().toString();
      _areaCtrl.text = prefs.preferredArea;
      setState(() {
        _wifi = prefs.wifiRequired;
        _ac = prefs.acRequired;
        _mess = prefs.messRequired;
        _roomType = prefs.roomType;
      });
      _fetchRecommendations(prefs);
    } else {
      _budgetCtrl.text = '30000';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    final prefs = UserPreferencesModel(
      userId: user.uid,
      maxBudget: double.parse(_budgetCtrl.text.trim()),
      preferredArea: _areaCtrl.text.trim(),
      wifiRequired: _wifi,
      acRequired: _ac,
      messRequired: _mess,
      roomType: _roomType,
    );

    try {
      await _recsService.savePreferences(prefs);
      _showSnack('Preferences saved successfully!', AppColors.success);
      _fetchRecommendations(prefs);
      _tabController.animateTo(1); // switch to recommendations tab
    } catch (e) {
      _showSnack('Error saving preferences: $e', AppColors.error);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _fetchRecommendations(UserPreferencesModel prefs) async {
    setState(() => _loadingRecs = true);
    Position? currentPos;
    try {
      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        status = await Geolocator.requestPermission();
      }
      if (status == LocationPermission.whileInUse || status == LocationPermission.always) {
        currentPos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
      }
    } catch (_) {}

    final list = await _recsService.getRecommendations(prefs, currentPos);
    if (mounted) {
      setState(() {
        _recommendations = list;
        _loadingRecs = false;
      });
    }
  }

  Future<void> _loadAiExplanation(HostelModel hostel, double score, double distance) async {
    if (_explanations.containsKey(hostel.id)) return; // already loaded
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _loadingExplanations[hostel.id] = true);
    final prefs = await _recsService.getPreferences(user.uid);
    if (prefs != null) {
      final explanation = await _recsService.generateRecommendationExplanation(prefs, hostel, score, distance);
      if (mounted) {
        setState(() {
          _explanations[hostel.id] = explanation;
          _loadingExplanations[hostel.id] = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingExplanations[hostel.id] = false);
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
        title: const Text('Smart AI Matchmaker', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
            Tab(text: 'Recommendations', icon: Icon(Icons.recommend)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPreferencesForm(),
          _buildRecommendationsFeed(),
        ],
      ),
    );
  }

  Widget _buildPreferencesForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Custom Fit Profile', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Input your lifestyle constraints so our engine can score matches.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Maximum Budget Per Month (PKR)',
            controller: _budgetCtrl,
            prefixIcon: Icons.currency_rupee,
            keyboardType: TextInputType.number,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Preferred Location / Area Name',
            controller: _areaCtrl,
            prefixIcon: Icons.my_location,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          const Text('Required Amenities', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _switchRow('High-speed Wi-Fi', _wifi, (v) => setState(() => _wifi = v)),
          _switchRow('Air Conditioning (AC)', _ac, (v) => setState(() => _ac = v)),
          _switchRow('Mess / Meals Included', _mess, (v) => setState(() => _mess = v)),
          const SizedBox(height: 20),
          const Text('Room Type', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: ['single', 'shared', 'any'].map((t) {
            final sel = _roomType == t;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _roomType = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 32),
          CustomButton(text: 'Calculate Match Recommendations', onPressed: _save, isLoading: _saving, icon: Icons.insights),
        ]),
      ),
    );
  }

  Widget _switchRow(String label, bool val, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Switch(value: val, onChanged: onChanged, activeThumbColor: AppColors.primary),
          ],
        ),
      );

  Widget _buildRecommendationsFeed() {
    if (_loadingRecs) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Running multi-weighted matching engine...', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    if (_recommendations.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.recommend_outlined, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('No recommendations computed.', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => _tabController.animateTo(0), child: const Text('Configure Preferences Settings')),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recommendations.length,
      itemBuilder: (_, i) {
        final item = _recommendations[i];
        final h = item['hostel'] as HostelModel;
        final score = item['score'] as double;
        final distance = item['distance'] as double;

        final isExpanded = _explanations.containsKey(h.id);
        final isLoadingEx = _loadingExplanations[h.id] ?? false;

        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: ExpansionTile(
            onExpansionChanged: (expanded) {
              if (expanded) {
                _loadAiExplanation(h, score, distance);
              }
            },
            title: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: score >= 80 ? AppColors.primaryGradient : null,
                  color: score < 80 ? AppColors.border : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${score.toStringAsFixed(0)}% Match', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(h.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            subtitle: Row(children: [
              Text('PKR ${h.pricePerMonth.toInt()}/mo', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (distance > 0.0) Text('${distance.toStringAsFixed(1)} km Away', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 4),
                  const Row(children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Text('Gemini AI Smart Explanation', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  if (isLoadingEx)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: AppColors.primary))
                  else if (isExpanded)
                    Text(_explanations[h.id]!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))
                  else
                    const Text('Expanding cards queries explanation layer...', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/student/hostel/${h.id}'),
                      icon: const Icon(Icons.visibility, color: Colors.white),
                      label: const Text('View Hostel Profile', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
