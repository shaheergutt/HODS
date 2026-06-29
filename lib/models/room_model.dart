class RoomModel {
  final String roomId;
  final String hostelId;
  final String roomNumber;
  final String roomType; // single, double, triple, quad, dormitory
  final int capacity;
  final int availableBeds;
  final int occupiedBeds;
  final double price;
  final bool isActive;
  final List<String> roomImages;
  final String description;
  final List<String> amenities;

  const RoomModel({
    required this.roomId,
    required this.hostelId,
    required this.roomNumber,
    required this.roomType,
    required this.capacity,
    required this.availableBeds,
    this.occupiedBeds = 0,
    required this.price,
    this.isActive = true,
    this.roomImages = const [],
    this.description = '',
    this.amenities = const [],
  });

  List<String> get images => roomImages;

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) {
    final cap = map['capacity'] ?? 1;
    final occ = map['occupiedBeds'] ?? 0;
    return RoomModel(
      roomId: id,
      hostelId: map['hostelId'] ?? '',
      roomNumber: map['roomNumber'] ?? map['roomName'] ?? '',
      roomType: (map['roomType'] as String?)?.toLowerCase() ?? 'single',
      capacity: cap,
      availableBeds: map['availableBeds'] ?? (cap - occ),
      occupiedBeds: occ,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] ?? true,
      roomImages: List<String>.from(map['roomImages'] ?? map['images'] ?? []),
      description: map['description'] ?? '',
      amenities: List<String>.from(map['amenities'] ?? map['facilities'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostelId': hostelId,
      'roomNumber': roomNumber,
      'roomType': roomType.toLowerCase(),
      'capacity': capacity,
      'availableBeds': availableBeds,
      'occupiedBeds': occupiedBeds,
      'price': price,
      'isActive': isActive,
      'roomImages': roomImages,
      'images': roomImages, // Alias for compatibility
      'description': description,
      'amenities': amenities,
    };
  }

  RoomModel copyWith({
    String? roomId,
    String? hostelId,
    String? roomNumber,
    String? roomType,
    int? capacity,
    int? availableBeds,
    int? occupiedBeds,
    double? price,
    bool? isActive,
    List<String>? roomImages,
    String? description,
    List<String>? amenities,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      hostelId: hostelId ?? this.hostelId,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      capacity: capacity ?? this.capacity,
      availableBeds: availableBeds ?? this.availableBeds,
      occupiedBeds: occupiedBeds ?? this.occupiedBeds,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      roomImages: roomImages ?? this.roomImages,
      description: description ?? this.description,
      amenities: amenities ?? this.amenities,
    );
  }
}
