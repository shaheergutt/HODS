class RoommateProfileModel {
  final String userId;
  final String userName;
  final String userEmail;
  final String profileImageUrl;
  final int age;
  final String gender;
  final String sleepTime; // e.g. "22:00", "00:00"
  final String wakeTime;
  final int studyHours;
  final bool smokingHabit;
  final bool gamingHabit;
  final String cleanlinessLevel; // 'high', 'medium', 'low'
  final String personalityType; // 'introvert', 'extrovert', 'ambivert'
  final List<String> interests;
  final String university;
  final int budgetMin;
  final int budgetMax;

  const RoommateProfileModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl = '',
    required this.age,
    required this.gender,
    required this.sleepTime,
    required this.wakeTime,
    required this.studyHours,
    required this.smokingHabit,
    required this.gamingHabit,
    required this.cleanlinessLevel,
    required this.personalityType,
    required this.interests,
    this.university = '',
    this.budgetMin = 0,
    this.budgetMax = 50000,
  });

  String get smokingPreference => smokingHabit ? 'Yes' : 'No';
  String get sleepSchedule => '$sleepTime - $wakeTime';
  String get studyHabit => '$studyHours hours';
  double get budget => budgetMax.toDouble();

  factory RoommateProfileModel.fromMap(Map<String, dynamic> map, String userId) {
    // Parse budget from any format
    int budgetMaxVal = 50000;
    if (map['budget'] != null) {
      budgetMaxVal = (map['budget'] as num).toInt();
    } else if (map['budgetMax'] != null) {
      budgetMaxVal = (map['budgetMax'] as num).toInt();
    }

    // Parse sleep/wake time from sleepSchedule
    String sleepTimeVal = map['sleepTime'] ?? '23:00';
    String wakeTimeVal = map['wakeTime'] ?? '07:00';
    if (map['sleepSchedule'] != null && map['sleepSchedule'] is String) {
      final parts = (map['sleepSchedule'] as String).split(' - ');
      if (parts.length == 2) {
        sleepTimeVal = parts[0];
        wakeTimeVal = parts[1];
      }
    }

    // Parse study hours from studyHabit
    int studyHoursVal = map['studyHours'] ?? 4;
    if (map['studyHabit'] != null && map['studyHabit'] is String) {
      final match = RegExp(r'^(\d+)').firstMatch(map['studyHabit'] as String);
      if (match != null) {
        studyHoursVal = int.tryParse(match.group(1) ?? '') ?? studyHoursVal;
      }
    }

    return RoommateProfileModel(
      userId: userId,
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      age: map['age'] ?? 20,
      gender: map['gender'] ?? 'mixed',
      sleepTime: sleepTimeVal,
      wakeTime: wakeTimeVal,
      studyHours: studyHoursVal,
      smokingHabit: map['smokingHabit'] ?? (map['smokingPreference'] == 'Yes'),
      gamingHabit: map['gamingHabit'] ?? false,
      cleanlinessLevel: map['cleanlinessLevel'] ?? 'medium',
      personalityType: map['personalityType'] ?? 'ambivert',
      interests: List<String>.from(map['interests'] ?? []),
      university: map['university'] ?? '',
      budgetMin: map['budgetMin'] ?? 0,
      budgetMax: budgetMaxVal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'profileImageUrl': profileImageUrl,
      'age': age,
      'gender': gender,
      'sleepTime': sleepTime,
      'wakeTime': wakeTime,
      'studyHours': studyHours,
      'smokingHabit': smokingHabit,
      'gamingHabit': gamingHabit,
      'cleanlinessLevel': cleanlinessLevel,
      'personalityType': personalityType,
      'interests': interests,
      'university': university,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      
      // Explicit fields required by user:
      'budget': budget,
      'studyHabit': studyHabit,
      'sleepSchedule': sleepSchedule,
      'smokingPreference': smokingPreference,
    };
  }
}
