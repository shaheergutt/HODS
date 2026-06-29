import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hostel_model.dart';
import '../../providers/hostel_provider.dart';

class HostelMapScreen extends ConsumerStatefulWidget {
  const HostelMapScreen({super.key});
  @override
  ConsumerState<HostelMapScreen> createState() => _HostelMapScreenState();
}

class _HostelMapScreenState extends ConsumerState<HostelMapScreen> {
  Position? _currentPosition;
  bool _loadingLocation = true;
  bool _showMapView = true;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _loadingLocation = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled. Using default coordinates.');
        setState(() => _loadingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permissions are denied. Using default coordinates.');
          setState(() => _loadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permissions are permanently denied.');
        setState(() => _loadingLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onMarkerTapped(HostelModel hostel, double distance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hostel.imageUrls.isNotEmpty
                    ? Image.network(hostel.imageUrls.first, width: 80, height: 80, fit: BoxFit.cover)
                    : Container(width: 80, height: 80, color: AppColors.primary, child: const Icon(Icons.home_work, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hostel.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(hostel.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('${hostel.rating} (${hostel.reviewCount} reviews)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ]),
              ),
            ]),
            const Divider(height: 24, color: AppColors.border),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Rent Per Month', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text('PKR ${hostel.pricePerMonth.toInt()}', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Distance', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text('${distance.toStringAsFixed(1)} km away', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchNavigation(hostel),
                  icon: const Icon(Icons.directions, color: AppColors.primary),
                  label: const Text('Directions', style: TextStyle(color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/student/hostel/${hostel.id}');
                  },
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  label: const Text('View Details', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _launchNavigation(HostelModel h) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${h.name}, ${h.location}, ${h.city}")}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not launch maps navigation');
    }
  }

  void _buildMarkers(List<HostelModel> hostels) {
    _markers.clear();
    for (final h in hostels) {
      if (h.latitude != 0.0 && h.longitude != 0.0) {
        final dist = _currentPosition != null
            ? Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, h.latitude, h.longitude) / 1000.0
            : 0.0;
        _markers.add(
          Marker(
            markerId: MarkerId(h.id),
            position: LatLng(h.latitude, h.longitude),
            infoWindow: InfoWindow(title: h.name, snippet: 'PKR ${h.pricePerMonth.toInt()}/mo'),
            onTap: () => _onMarkerTapped(h, dist),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostelsAsync = ref.watch(allHostelsProvider);

    return Scaffold(
      body: hostelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (hostels) {
          final mappedHostels = hostels.where((h) => h.isApproved).toList();
          _buildMarkers(mappedHostels);

          final initialTarget = _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(33.6844, 73.0479); // Islamabad default

          return _showMapView
              ? Stack(children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: initialTarget, zoom: 13),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _markers,
                    onMapCreated: (ctrl) {},
                  ),
                  Positioned(
                    top: 50, left: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/student');
                          }
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50, right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: Icon(_showMapView ? Icons.view_list : Icons.map_outlined, color: Colors.white),
                        onPressed: () => setState(() => _showMapView = !_showMapView),
                      ),
                    ),
                  ),
                  if (_loadingLocation)
                    Positioned(
                      top: 100, left: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Locking current GPS coordinates...',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),
                ])
              : Scaffold(
                  appBar: AppBar(
                    backgroundColor: AppColors.background,
                    title: const Text('Nearby Hostels Radar', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
                        icon: const Icon(Icons.map, color: AppColors.primary),
                        onPressed: () => setState(() => _showMapView = !_showMapView),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.background,
                  body: _buildRadarList(mappedHostels),
                );
        },
      ),
    );
  }

  Widget _buildRadarList(List<HostelModel> hostels) {
    final list = hostels.map((h) {
      final distance = _currentPosition != null
          ? Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, h.latitude, h.longitude) / 1000.0
          : 4.8; // fallback
      return {'hostel': h, 'distance': distance};
    }).toList();

    list.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final h = item['hostel'] as HostelModel;
        final d = item['distance'] as double;
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: h.imageUrls.isNotEmpty
                  ? Image.network(h.imageUrls.first, width: 60, height: 60, fit: BoxFit.cover)
                  : Container(width: 60, height: 60, color: AppColors.primary, child: const Icon(Icons.home_work, color: Colors.white)),
            ),
            title: Text(h.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${h.location}, ${h.city}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.radar, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${d.toStringAsFixed(1)} km away', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ]),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('PKR ${h.pricePerMonth.toInt()}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const Text('/mo', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ]),
            onTap: () => _onMarkerTapped(h, d),
          ),
        );
      },
    );
  }
}
