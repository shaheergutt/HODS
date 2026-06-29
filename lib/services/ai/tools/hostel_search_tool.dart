import '../tool_interface.dart';
import '../ai_types.dart';
import '../firestore_context_service.dart';
import '../recommendation_engine.dart';
import '../../../models/user_model.dart';

class HostelSearchTool implements BaseTool {
  final FirestoreContextService _contextService = FirestoreContextService();
  final RecommendationEngine _recEngine = RecommendationEngine();

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = arguments['toolName']?.toString() ?? 'searchHostels';
    try {
      final hostels = await _contextService.getApprovedHostels();
      final rooms = await _contextService.getActiveRooms();

      if (toolName == 'searchNearbyHostels') {
        final lat = (arguments['latitude'] as num).toDouble();
        final lng = (arguments['longitude'] as num).toDouble();
        final ranked = _recEngine.rankHostels(
          hostels: hostels,
          rooms: rooms,
          weights: RecommendationWeights(price: 0.1, distance: 0.7, rating: 0.1, amenities: 0.1),
          budget: 50000.0,
          stayType: 'monthly',
          targetCoordinates: {'lat': lat, 'lng': lng},
        );
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {'results': ranked.take(5).toList()},
          executionTime: elapsed,
          metadata: {'latitude': lat, 'longitude': lng},
        );
      }

      if (toolName == 'compareHostels') {
        final hostelIds = List<String>.from(arguments['hostelIds'] ?? []);
        final matching = hostels.where((h) => hostelIds.contains(h.id)).toList();
        final results = matching.map((h) {
          final hostelRooms = rooms.where((r) => r.hostelId == h.id).toList();
          return {
            'id': h.id,
            'name': h.name,
            'pricePerMonth': h.pricePerMonth,
            'pricePerDay': h.pricePerDay,
            'rating': h.rating,
            'facilities': h.facilities,
            'location': h.location,
            'city': h.city,
            'roomTypes': hostelRooms.map((r) => r.roomType).toSet().toList(),
          };
        }).toList();
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {'results': results},
          executionTime: elapsed,
          metadata: {'hostelsCount': results.length},
        );
      }

      if (toolName == 'getHostelDetails') {
        final hostelId = arguments['hostelId']?.toString();
        final matching = hostels.where((h) => h.id == hostelId).toList();
        if (matching.isEmpty) {
          throw Exception('Hostel not found');
        }
        final hostelRooms = rooms.where((r) => r.hostelId == hostelId).toList();
        final elapsed = DateTime.now().difference(startTime);
        return ToolResult(
          toolName: toolName,
          success: true,
          data: {
            'hostel': matching.first.toMap(),
            'roomsAvailable': hostelRooms.map((r) => r.toMap()).toList()
          },
          executionTime: elapsed,
          metadata: {'hostelId': hostelId},
        );
      }

      // Default Search
      final city = arguments['city']?.toString();
      final budget = (arguments['budget'] ?? 25000.0).toDouble();
      final university = arguments['university']?.toString();
      final roomType = arguments['roomType']?.toString();
      final stayType = arguments['stayType']?.toString() ?? 'monthly';

      Map<String, double>? targetCoordinates;
      if (university != null) {
        targetCoordinates = await _contextService.getUniversityCoordinates(university);
      } else if (city != null) {
        targetCoordinates = await _contextService.getCityCoordinates(city);
      }

      final ranked = _recEngine.rankHostels(
        hostels: hostels,
        rooms: rooms,
        weights: RecommendationWeights(price: 0.25, distance: 0.40, rating: 0.20, amenities: 0.15),
        budget: budget,
        stayType: stayType,
        targetCoordinates: targetCoordinates,
        userRoomType: roomType,
      );

      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: {'results': ranked.take(5).toList()},
        executionTime: elapsed,
        metadata: {'city': city, 'budget': budget, 'university': university},
      );
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: false,
        data: {},
        error: e.toString(),
        executionTime: elapsed,
        metadata: {},
      );
    }
  }
}
