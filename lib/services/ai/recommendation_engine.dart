import 'dart:math';
import '../../models/hostel_model.dart';
import '../../models/room_model.dart';
import 'ai_types.dart';

class RecommendationEngine {
  /// Haversine distance calculator
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Calculates dynamic scores for hostels based on custom weights
  List<Map<String, dynamic>> rankHostels({
    required List<HostelModel> hostels,
    required List<RoomModel> rooms,
    required RecommendationWeights weights,
    required double budget,
    required String stayType,
    Map<String, double>? targetCoordinates,
    String? userRoomType,
  }) {
    final recommendations = <Map<String, dynamic>>[];

    for (final h in hostels) {
      // Find rooms for this hostel
      final hostelRooms = rooms.where((r) => r.hostelId == h.id).toList();
      final availableRoomTypes = hostelRooms.map((r) => r.roomType).toSet().toList();

      double priceToUse = h.pricePerMonth;
      double roomTypeMultiplier = 1.0;

      if (userRoomType != null) {
        final isSingle = userRoomType.toLowerCase() == 'single';
        if (isSingle) {
          if (!availableRoomTypes.contains('single')) {
            roomTypeMultiplier = 0.2; // Penalize if single room is not available
          } else {
            final lowestSingle = hostelRooms
                .where((r) => r.roomType == 'single')
                .map((r) => r.price)
                .fold<double?>(null, (min, p) => min == null ? p : (p < min ? p : min));
            if (lowestSingle != null) {
              priceToUse = lowestSingle;
            }
          }
        } else {
          final sharedTypes = availableRoomTypes.where((t) => t != 'single').toList();
          if (sharedTypes.isEmpty) {
            roomTypeMultiplier = 0.2; // Penalize if shared room is not available
          } else {
            final lowestShared = hostelRooms
                .where((r) => r.roomType != 'single')
                .map((r) => r.price)
                .fold<double?>(null, (min, p) => min == null ? p : (p < min ? p : min));
            if (lowestShared != null) {
              priceToUse = lowestShared;
            }
          }
        }
      }

      // 1. Distance score calculation
      double distanceInKm = 4.8;
      double distanceScore = 60.0;

      if (targetCoordinates != null && h.latitude != 0.0 && h.longitude != 0.0) {
        distanceInKm = calculateDistance(
          targetCoordinates['lat']!,
          targetCoordinates['lng']!,
          h.latitude,
          h.longitude,
        );
        if (distanceInKm <= 1.0) {
          distanceScore = 100.0;
        } else if (distanceInKm <= 3.0) {
          distanceScore = 80.0;
        } else if (distanceInKm <= 5.0) {
          distanceScore = 60.0;
        } else if (distanceInKm <= 10.0) {
          distanceScore = 40.0;
        } else {
          distanceScore = 20.0;
        }
      }

      // 2. Price score calculation
      double priceScore = 100.0;
      if (stayType == 'daily') {
        final dailyPrice = h.pricePerDay;
        final dailyBudget = budget < 10000 ? budget : 2500.0;
        if (dailyPrice > dailyBudget) {
          final diff = dailyPrice - dailyBudget;
          priceScore = max(0.0, 100.0 - (diff / dailyBudget * 100.0));
        }
      } else {
        if (priceToUse > budget) {
          final diff = priceToUse - budget;
          priceScore = max(0.0, 100.0 - (diff / budget * 100.0));
        }
      }

      // 3. Rating score calculation
      final ratingScore = h.rating * 20.0;

      // 4. Amenities/Facilities matching score
      final amenitiesScore = h.facilities.isNotEmpty ? 90.0 : 40.0;

      // Compute total weighted score
      double score = (priceScore * weights.price) +
          (distanceScore * weights.distance) +
          (ratingScore * weights.rating) +
          (amenitiesScore * weights.amenities);

      // Apply multiplier penalities
      score *= roomTypeMultiplier;

      recommendations.add({
        'id': h.id,
        'name': h.name,
        'location': h.location,
        'city': h.city,
        'pricePerMonth': h.pricePerMonth,
        'pricePerDay': h.pricePerDay,
        'priceToUse': priceToUse,
        'rating': h.rating,
        'distance': distanceInKm,
        'score': score.clamp(0.0, 100.0),
        'facilities': h.facilities,
        'genderPolicy': h.genderPolicy,
        'roomTypes': availableRoomTypes,
        'hasSingleRoom': availableRoomTypes.contains('single'),
        'hasSharedRoom': availableRoomTypes.any((t) => t != 'single'),
        'availableRooms': h.availableRooms,
      });
    }

    recommendations.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return recommendations;
  }
}
