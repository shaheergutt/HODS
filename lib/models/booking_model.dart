import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }

// Added QR and check-in/out fields to booking model

enum BookingType { monthly, daily }

class BookingModel {
  final String id;
  final String studentId;
  final String studentName;
  final String hostelId;
  final String hostelName;
  final String ownerId;
  
  // QR and check-in/out fields
  final String? qrToken;
  final DateTime? qrGeneratedAt;
  final bool checkedIn;
  final bool checkedOut;
  final String roomId;
  final String roomNumber;
  final String roomType;
  final int bedsBooked;

  final DateTime checkInDate;
  final DateTime checkOutDate;
  final BookingStatus status;
  final double totalAmount;
  final int durationMonths;
  final int durationDays;
  final BookingType bookingType;
  final String specialRequests;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostelId,
    required this.hostelName,
    required this.ownerId,
    this.qrToken,
    this.qrGeneratedAt,
    this.checkedIn = false,
    this.checkedOut = false,
    required this.roomId,
    this.roomNumber = '',
    this.roomType = '',
    this.bedsBooked = 1,
    required this.checkInDate,
    required this.checkOutDate,
    required this.status,
    required this.totalAmount,
    this.durationMonths = 1,
    this.durationDays = 0,
    this.bookingType = BookingType.monthly,
    this.specialRequests = '',
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return BookingModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      hostelId: map['hostelId'] ?? '',
      hostelName: map['hostelName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      qrToken: map['qrToken'],
      qrGeneratedAt: map['qrGeneratedAt'] != null ? (map['qrGeneratedAt'] is Timestamp ? (map['qrGeneratedAt'] as Timestamp).toDate() : DateTime.tryParse(map['qrGeneratedAt']) ?? DateTime.now()) : null,
      checkedIn: map['checkedIn'] ?? false,
      checkedOut: map['checkedOut'] ?? false,
      roomId: map['roomId'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
      roomType: map['roomType'] ?? '',
      bedsBooked: map['bedsBooked'] ?? 1,
      checkInDate: parseDate(map['checkInDate']),
      checkOutDate: parseDate(map['checkOutDate']),
      status: _statusFromString(map['status'] ?? 'pending'),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      durationMonths: map['durationMonths'] ?? 1,
      durationDays: map['durationDays'] ?? 0,
      bookingType: _typeFromString(map['bookingType'] ?? 'monthly'),
      specialRequests: map['specialRequests'] ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'hostelId': hostelId,
      'hostelName': hostelName,
      'ownerId': ownerId,
      'qrToken': qrToken,
      'qrGeneratedAt': qrGeneratedAt != null ? Timestamp.fromDate(qrGeneratedAt!) : null,
      'checkedIn': checkedIn,
      'checkedOut': checkedOut,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'roomType': roomType,
      'bedsBooked': bedsBooked,
      'checkInDate': Timestamp.fromDate(checkInDate),
      'checkOutDate': Timestamp.fromDate(checkOutDate),
      'status': status.name,
      'totalAmount': totalAmount,
      'durationMonths': durationMonths,
      'durationDays': durationDays,
      'bookingType': bookingType.name,
      'specialRequests': specialRequests,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  BookingModel copyWith({
    BookingStatus? status,
    String? roomId,
    String? roomNumber,
    String? roomType,
    int? bedsBooked,
    bool? checkedIn,
    bool? checkedOut,
  }) {
    return BookingModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      hostelId: hostelId,
      hostelName: hostelName,
      ownerId: ownerId,
      qrToken: qrToken,
      qrGeneratedAt: qrGeneratedAt,
      checkedIn: checkedIn ?? this.checkedIn,
      checkedOut: checkedOut ?? this.checkedOut,
      roomId: roomId ?? this.roomId,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      bedsBooked: bedsBooked ?? this.bedsBooked,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      status: status ?? this.status,
      totalAmount: totalAmount,
      durationMonths: durationMonths,
      durationDays: durationDays,
      bookingType: bookingType,
      specialRequests: specialRequests,
      createdAt: createdAt,
    );
  }

  static BookingStatus _statusFromString(String s) {
    switch (s) {
      case 'confirmed': return BookingStatus.confirmed;
      case 'cancelled': return BookingStatus.cancelled;
      case 'completed': return BookingStatus.completed;
      default: return BookingStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending: return 'Pending';
      case BookingStatus.confirmed: return 'Confirmed';
      case BookingStatus.cancelled: return 'Cancelled';
      case BookingStatus.completed: return 'Completed';
    }
  }

  static BookingType _typeFromString(String s) {
    if (s == 'daily') return BookingType.daily;
    return BookingType.monthly;
  }
}
