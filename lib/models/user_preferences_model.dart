class UserPreferencesModel {
  final String userId;
  final double maxBudget;
  final String preferredArea;
  final bool wifiRequired;
  final bool acRequired;
  final bool messRequired;
  final String roomType; // 'single', 'shared', 'any'

  const UserPreferencesModel({
    required this.userId,
    required this.maxBudget,
    required this.preferredArea,
    required this.wifiRequired,
    required this.acRequired,
    required this.messRequired,
    required this.roomType,
  });

  factory UserPreferencesModel.fromMap(Map<String, dynamic> map, String userId) {
    return UserPreferencesModel(
      userId: userId,
      maxBudget: (map['maxBudget'] ?? 50000.0).toDouble(),
      preferredArea: map['preferredArea'] ?? '',
      wifiRequired: map['wifiRequired'] ?? false,
      acRequired: map['acRequired'] ?? false,
      messRequired: map['messRequired'] ?? false,
      roomType: map['roomType'] ?? 'any',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxBudget': maxBudget,
      'preferredArea': preferredArea,
      'wifiRequired': wifiRequired,
      'acRequired': acRequired,
      'messRequired': messRequired,
      'roomType': roomType,
    };
  }
}
