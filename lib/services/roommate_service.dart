import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/roommate_profile_model.dart';
import '../models/roommate_request_model.dart';
import 'package:uuid/uuid.dart';

class RoommateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Gemini config
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
  GenerativeModel? _model;

  RoommateService() {
    if (_apiKey.isNotEmpty && _apiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      try {
        _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      } catch (_) {}
    }
  }

  Future<void> saveProfile(RoommateProfileModel profile) async {
    await _db.collection('roommate_profiles').doc(profile.userId).set(profile.toMap());
  }

  Future<RoommateProfileModel?> getProfile(String userId) async {
    final doc = await _db.collection('roommate_profiles').doc(userId).get();
    if (!doc.exists) return null;
    return RoommateProfileModel.fromMap(doc.data()!, userId);
  }

  double _getHourDiff(String t1, String t2) {
    try {
      final p1 = t1.split(':');
      final p2 = t2.split(':');
      final h1 = int.parse(p1[0]);
      final m1 = int.parse(p1[1]);
      final h2 = int.parse(p2[0]);
      final m2 = int.parse(p2[1]);
      final min1 = h1 * 60 + m1;
      final min2 = h2 * 60 + m2;
      int diff = (min1 - min2).abs();
      if (diff > 720) diff = 1440 - diff; // wrap around clock
      return diff / 60.0;
    } catch (_) {
      return 0.0;
    }
  }

  int _cleanlinessVal(String level) {
    if (level == 'high') return 2;
    if (level == 'medium') return 1;
    return 0;
  }

  Future<List<Map<String, dynamic>>> getMatches(RoommateProfileModel userProfile) async {
    final snap = await _db.collection('roommate_profiles').get();
    final profiles = snap.docs
        .map((d) => RoommateProfileModel.fromMap(d.data(), d.id))
        .where((p) => p.userId != userProfile.userId && p.gender == userProfile.gender)
        .toList();

    final matchesList = <Map<String, dynamic>>[];

    for (final p in profiles) {
      // 1. Budget Match = 25%
      double budgetScore = 0.0;
      final budgetDiff = (p.budget - userProfile.budget).abs();
      budgetScore = max(0.0, 100.0 - (budgetDiff / 1000.0) * 5.0);

      // 2. University Match = 15%
      double universityScore = 0.0;
      if (p.university.isNotEmpty && userProfile.university.isNotEmpty &&
          p.university.trim().toLowerCase() == userProfile.university.trim().toLowerCase()) {
        universityScore = 100.0;
      }

      // 3. Study Habit Match = 20%
      final studyDiff = (p.studyHours - userProfile.studyHours).abs();
      double studyScore = max(0.0, 100.0 - (studyDiff * 15.0));

      // 4. Sleep Schedule Match = 15%
      final sleepDiff = _getHourDiff(p.sleepTime, userProfile.sleepTime);
      final wakeDiff = _getHourDiff(p.wakeTime, userProfile.wakeTime);
      double sleepScore = max(0.0, 100.0 - (sleepDiff + wakeDiff) * 20.0);

      // 5. Cleanliness Match = 15%
      final cleanDiff = (_cleanlinessVal(p.cleanlinessLevel) - _cleanlinessVal(userProfile.cleanlinessLevel)).abs();
      double cleanlinessScore = max(0.0, 100.0 - (cleanDiff * 50.0));

      // 6. Smoking Preference Match = 10%
      double smokingScore = (p.smokingHabit == userProfile.smokingHabit) ? 100.0 : 0.0;

      // Calculate final weighted compatibility score
      final score = (budgetScore * 0.25) +
          (universityScore * 0.15) +
          (studyScore * 0.20) +
          (sleepScore * 0.15) +
          (cleanlinessScore * 0.15) +
          (smokingScore * 0.10);

      matchesList.add({
        'profile': p,
        'score': score.clamp(0.0, 100.0),
      });
    }

    // Sort by compatibility descending
    matchesList.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Return top 10 compatible roommates
    return matchesList.take(10).toList();
  }

  // ════════════════════════════════════════════════════
  // ROOMMATE REQUESTS & CONNECTIONS
  // ════════════════════════════════════════════════════

  Future<void> sendRoommateRequest({
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String receiverId,
    required String receiverName,
    required String receiverImageUrl,
  }) async {
    final id = _uuid.v4();
    final request = RoommateRequestModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderImageUrl: senderImageUrl,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverImageUrl: receiverImageUrl,
      status: RoommateRequestStatus.pending,
      timestamp: DateTime.now(),
    );
    await _db.collection('roommate_requests').doc(id).set(request.toMap());
  }

  Stream<List<RoommateRequestModel>> getIncomingRequests(String userId) {
    return _db
        .collection('roommate_requests')
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RoommateRequestModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Stream<List<RoommateRequestModel>> getOutgoingRequests(String userId) {
    return _db
        .collection('roommate_requests')
        .where('senderId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RoommateRequestModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  Future<void> updateRoommateRequestStatus(String requestId, RoommateRequestStatus status) async {
    await _db.collection('roommate_requests').doc(requestId).update({'status': status.name});
  }

  Future<RoommateRequestModel?> getActiveRequestBetween(String userA, String userB) async {
    final q1 = await _db
        .collection('roommate_requests')
        .where('senderId', isEqualTo: userA)
        .where('receiverId', isEqualTo: userB)
        .get();
    if (q1.docs.isNotEmpty) {
      return RoommateRequestModel.fromMap(q1.docs.first.data(), q1.docs.first.id);
    }

    final q2 = await _db
        .collection('roommate_requests')
        .where('senderId', isEqualTo: userB)
        .where('receiverId', isEqualTo: userA)
        .get();
    if (q2.docs.isNotEmpty) {
      return RoommateRequestModel.fromMap(q2.docs.first.data(), q2.docs.first.id);
    }

    return null;
  }

  Future<String> generateRoommateExplanation(
    RoommateProfileModel myProfile,
    RoommateProfileModel matchProfile,
    double score,
  ) async {
    final prompt = """
Calculate roommate compatibility explanation for HODS Roommate Matchmaker:
My Profile:
Age: ${myProfile.age}
Sleep Time: ${myProfile.sleepTime}
Wake Time: ${myProfile.wakeTime}
Study Hours: ${myProfile.studyHours} hours
Smoking: ${myProfile.smokingHabit ? 'Yes' : 'No'}
Gaming: ${myProfile.gamingHabit ? 'Yes' : 'No'}
Cleanliness: ${myProfile.cleanlinessLevel}
Interests: ${myProfile.interests.join(', ')}

Match Roommate: ${matchProfile.userName}
Age: ${matchProfile.age}
Sleep Time: ${matchProfile.sleepTime}
Wake Time: ${matchProfile.wakeTime}
Study Hours: ${matchProfile.studyHours} hours
Smoking: ${matchProfile.smokingHabit ? 'Yes' : 'No'}
Gaming: ${matchProfile.gamingHabit ? 'Yes' : 'No'}
Cleanliness: ${matchProfile.cleanlinessLevel}
Interests: ${matchProfile.interests.join(', ')}

Compatibility Score: ${score.toStringAsFixed(0)}%

Briefly generate 2 sentences explaining why they are highly compatible (e.g. sleep cycles, smoking habits, shared interests). Be friendly.
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

    // Heuristic local fallback
    final commonInterests = matchProfile.interests.where((i) => myProfile.interests.contains(i)).toList();
    final buffer = StringBuffer();
    buffer.write("You both have a ${score.toStringAsFixed(0)}% roommate compatibility score. ");
    if (myProfile.sleepTime == matchProfile.sleepTime && myProfile.wakeTime == matchProfile.wakeTime) {
      buffer.write("You share matching sleeping cycles (${myProfile.sleepTime} sleep, ${myProfile.wakeTime} wake). ");
    }
    if (myProfile.smokingHabit == matchProfile.smokingHabit) {
      buffer.write(myProfile.smokingHabit ? "Both of you share similar smoking preferences. " : "Both of you prefer a smoke-free roommate environment. ");
    }
    if (myProfile.cleanlinessLevel == matchProfile.cleanlinessLevel) {
      buffer.write("Additionally, you both maintain a ${myProfile.cleanlinessLevel} cleanliness level. ");
    }
    if (commonInterests.isNotEmpty) {
      buffer.write("You also share hobbies like ${commonInterests.take(2).join(' and ')}.");
    }
    return buffer.toString();
  }
}
