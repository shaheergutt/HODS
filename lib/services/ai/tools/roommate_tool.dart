import 'package:cloud_firestore/cloud_firestore.dart';
import '../tool_interface.dart';
import '../ai_types.dart';
import '../../roommate_service.dart';
import '../../../models/user_model.dart';
import '../../../models/roommate_profile_model.dart';

class RoommateTool implements BaseTool {
  final RoommateService _roommateService = RoommateService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final toolName = 'findRoommates';
    try {
      if (role != UserRole.student) {
        throw Exception('Only students can match roommate profiles.');
      }
      final myProfileDoc = await _db.collection('roommate_profiles').doc(userId).get();
      if (!myProfileDoc.exists) {
        throw Exception('No roommate profile setup found for the current student.');
      }
      final myProfile = RoommateProfileModel.fromMap(myProfileDoc.data()!, userId);
      final matches = await _roommateService.getMatches(myProfile);
      
      final results = matches.map((m) {
        final p = m['profile'] as RoommateProfileModel;
        return {
          'userId': p.userId,
          'name': p.userName,
          'university': p.university,
          'age': p.age,
          'budget': p.budget,
          'studyHours': p.studyHours,
          'sleepTime': p.sleepTime,
          'cleanlinessLevel': p.cleanlinessLevel,
          'compatibility': m['score'],
          'profileImageUrl': p.profileImageUrl,
        };
      }).toList();

      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: true,
        data: {'results': results},
        executionTime: elapsed,
        metadata: {'matchesFound': results.length},
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
