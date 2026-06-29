import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/hostel_model.dart';
import '../models/user_preferences_model.dart';

class RecommendationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Gemini config
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
  GenerativeModel? _model;

  RecommendationService() {
    if (_apiKey.isNotEmpty && _apiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      try {
        _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      } catch (_) {}
    }
  }

  Future<void> savePreferences(UserPreferencesModel prefs) async {
    await _db.collection('user_preferences').doc(prefs.userId).set(prefs.toMap());
  }

  Future<UserPreferencesModel?> getPreferences(String userId) async {
    final doc = await _db.collection('user_preferences').doc(userId).get();
    if (!doc.exists) return null;
    return UserPreferencesModel.fromMap(doc.data()!, userId);
  }

  Future<List<Map<String, dynamic>>> getRecommendations(
    UserPreferencesModel prefs,
    Position? currentPos,
  ) async {
    // Fetch all approved hostels
    final snap = await _db.collection('hostels').where('isApproved', isEqualTo: true).get();
    final hostels = snap.docs.map((d) => HostelModel.fromMap(d.data(), d.id)).toList();

    final scoredList = <Map<String, dynamic>>[];

    for (final h in hostels) {
      // a. Distance Score (30%)
      double distanceInKm = 0.0;
      double distanceScore = 60.0; // default if no position
      if (currentPos != null && h.latitude != 0.0 && h.longitude != 0.0) {
        final dist = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          h.latitude,
          h.longitude,
        );
        distanceInKm = dist / 1000.0;
        if (distanceInKm <= 1.0) {
          distanceScore = 100.0;
        } else if (distanceInKm <= 3.0) {
          distanceScore = 80.0;
        } else if (distanceInKm <= 5.0) {
          distanceScore = 60.0;
        } else {
          distanceScore = 30.0;
        }
      }

      // b. Budget Score (25%)
      double budgetScore = 100.0;
      if (h.pricePerMonth > prefs.maxBudget) {
        final diff = h.pricePerMonth - prefs.maxBudget;
        budgetScore = max(0.0, 100.0 - (diff / prefs.maxBudget * 100.0));
      }

      // c. Facilities Score (20%)
      int matchCount = 0;
      int totalRequired = 0;
      if (prefs.wifiRequired) {
        totalRequired++;
        if (h.facilities.any((f) => f.toLowerCase().contains('wifi') || f.toLowerCase().contains('internet'))) {
          matchCount++;
        }
      }
      if (prefs.acRequired) {
        totalRequired++;
        if (h.facilities.any((f) => f.toUpperCase().contains('AC') || f.toLowerCase().contains('condition'))) {
          matchCount++;
        }
      }
      if (prefs.messRequired) {
        totalRequired++;
        if (h.facilities.any((f) => f.toLowerCase().contains('mess') || f.toLowerCase().contains('food') || f.toLowerCase().contains('meal'))) {
          matchCount++;
        }
      }
      double facilitiesScore = totalRequired == 0 ? 100.0 : (matchCount / totalRequired * 100.0);

      // d. Rating Score (15%)
      double ratingScore = h.rating * 20.0; // rating is 0 to 5 -> scale to 0-100

      // e. Vacancy Score (10%)
      double vacancyScore = h.availableRooms > 0 ? 100.0 : 0.0;

      // Final match score
      double score = (distanceScore * 0.30) +
          (budgetScore * 0.25) +
          (facilitiesScore * 0.20) +
          (ratingScore * 0.15) +
          (vacancyScore * 0.10);

      scoredList.add({
        'hostel': h,
        'score': score.clamp(0.0, 100.0),
        'distance': distanceInKm,
      });
    }

    // Sort by score descending
    scoredList.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Return top 10
    return scoredList.take(10).toList();
  }

  Future<String> generateRecommendationExplanation(
    UserPreferencesModel prefs,
    HostelModel hostel,
    double score,
    double distance,
  ) async {
    final prompt = """
Calculate explanation for HODS Hostel recommendation:
Target Hostel: ${hostel.name}
City: ${hostel.city}
Rent: PKR ${hostel.pricePerMonth}
Rating: ${hostel.rating}
Amenities: ${hostel.facilities.join(', ')}

Student Preference:
Max Budget: PKR ${prefs.maxBudget}
Area: ${prefs.preferredArea}
WiFi Required: ${prefs.wifiRequired}
AC Required: ${prefs.acRequired}

Recommendation Stats:
Match Score: ${score.toStringAsFixed(1)}%
Calculated Distance: ${distance.toStringAsFixed(1)} km

Briefly generate 2-3 sentences explaining exactly why this hostel matches the student's preferences and budget. Be polite, friendly, and structured.
""";

    if (_model != null) {
      try {
        final content = [Content.text(prompt)];
        final resp = await _model!.generateContent(content);
        if (resp.text != null && resp.text!.isNotEmpty) {
          return resp.text!;
        }
      } catch (_) {}
    }

    // Local fallback explanation generator
    final buffer = StringBuffer();
    buffer.write("This hostel is recommended with a ${score.toStringAsFixed(0)}% compatibility match score. ");
    if (hostel.pricePerMonth <= prefs.maxBudget) {
      buffer.write("It fits perfectly within your budget of PKR ${prefs.maxBudget.toInt()}/mo (Rent: PKR ${hostel.pricePerMonth.toInt()}/mo). ");
    } else {
      buffer.write("It is slightly above your preferred budget, but offers premium value. ");
    }
    if (distance > 0.0) {
      buffer.write("It is located just ${distance.toStringAsFixed(1)} km away. ");
    }
    buffer.write("Additionally, it provides amenities like ${hostel.facilities.take(3).join(', ')} matching your lifestyle.");
    return buffer.toString();
  }
}
