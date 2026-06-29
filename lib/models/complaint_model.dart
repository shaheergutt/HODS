import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus {
  pending,
  assigned,
  inProgress,
  waitingForStudent,
  resolved,
  closed,
  rejected,
  reopened;

  String get statusLabel {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.assigned:
        return 'Assigned';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.waitingForStudent:
        return 'Waiting for Student';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.closed:
        return 'Closed';
      case ComplaintStatus.rejected:
        return 'Rejected';
      case ComplaintStatus.reopened:
        return 'Reopened';
    }
  }
}

enum ComplaintPriority {
  low,
  medium,
  high,
  urgent;

  String get priorityLabel {
    switch (this) {
      case ComplaintPriority.low:
        return 'Low';
      case ComplaintPriority.medium:
        return 'Medium';
      case ComplaintPriority.high:
        return 'High';
      case ComplaintPriority.urgent:
        return 'Urgent';
    }
  }
}

class TimelineEntry {
  final String title;
  final String actor;
  final String description;
  final DateTime timestamp;

  const TimelineEntry({
    required this.title,
    required this.actor,
    required this.description,
    required this.timestamp,
  });

  factory TimelineEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }
    return TimelineEntry(
      title: map['title'] ?? '',
      actor: map['actor'] ?? '',
      description: map['description'] ?? '',
      timestamp: parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'actor': actor,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class ComplaintModel {
  final String id;
  final String studentId;
  final String studentName;
  final String hostelId;
  final String hostelName;
  // Denormalized field — required for owner-side Firestore queries
  final String hostelOwnerId;
  final String? bookingId;
  final String title;
  final String description;
  final String category;
  final ComplaintPriority priority;
  final ComplaintStatus status;
  final int rating;
  final String ownerReply;
  final String studentResponse;
  final List<String> attachments;
  final List<TimelineEntry> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  const ComplaintModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostelId,
    required this.hostelName,
    required this.hostelOwnerId,
    this.bookingId,
    required this.title,
    required this.description,
    required this.category,
    this.priority = ComplaintPriority.medium,
    this.status = ComplaintStatus.pending,
    this.rating = 0,
    this.ownerReply = '',
    this.studentResponse = '',
    this.attachments = const [],
    this.timeline = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
  });

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawTimeline = map['timeline'] as List<dynamic>? ?? [];
    final timelineList = rawTimeline
        .map((e) => TimelineEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return ComplaintModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      hostelId: map['hostelId'] ?? '',
      hostelName: map['hostelName'] ?? '',
      hostelOwnerId: map['hostelOwnerId'] ?? '',
      bookingId: map['bookingId'] as String?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Other',
      priority: _priorityFromString(map['priority'] ?? 'medium'),
      status: _statusFromString(map['status'] ?? 'pending'),
      rating: (map['rating'] ?? 0) as int,
      ownerReply: map['ownerReply'] ?? '',
      studentResponse: map['studentResponse'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      timeline: timelineList,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt'] ?? map['createdAt']),
      resolvedAt: parseNullableDate(map['resolvedAt']),
      closedAt: parseNullableDate(map['closedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'hostelId': hostelId,
      'hostelName': hostelName,
      'hostelOwnerId': hostelOwnerId,
      'bookingId': bookingId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.name,
      'status': status.name,
      'rating': rating,
      'ownerReply': ownerReply,
      'studentResponse': studentResponse,
      'attachments': attachments,
      'timeline': timeline.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    };
  }

  ComplaintModel copyWith({
    ComplaintStatus? status,
    ComplaintPriority? priority,
    int? rating,
    String? ownerReply,
    String? studentResponse,
    List<String>? attachments,
    List<TimelineEntry>? timeline,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
  }) {
    return ComplaintModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      hostelId: hostelId,
      hostelName: hostelName,
      hostelOwnerId: hostelOwnerId,
      bookingId: bookingId,
      title: title,
      description: description,
      category: category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      ownerReply: ownerReply ?? this.ownerReply,
      studentResponse: studentResponse ?? this.studentResponse,
      attachments: attachments ?? this.attachments,
      timeline: timeline ?? this.timeline,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  static ComplaintStatus _statusFromString(String s) {
    switch (s) {
      case 'pending':
        return ComplaintStatus.pending;
      case 'assigned':
        return ComplaintStatus.assigned;
      case 'inProgress':
        return ComplaintStatus.inProgress;
      case 'waitingForStudent':
        return ComplaintStatus.waitingForStudent;
      case 'resolved':
        return ComplaintStatus.resolved;
      case 'closed':
        return ComplaintStatus.closed;
      case 'rejected':
        return ComplaintStatus.rejected;
      case 'reopened':
        return ComplaintStatus.reopened;
      default:
        // Keep compatibility with older database documents
        if (s == 'open') return ComplaintStatus.pending;
        return ComplaintStatus.pending;
    }
  }

  static ComplaintPriority _priorityFromString(String s) {
    switch (s) {
      case 'low':
        return ComplaintPriority.low;
      case 'high':
        return ComplaintPriority.high;
      case 'urgent':
        return ComplaintPriority.urgent;
      default:
        return ComplaintPriority.medium;
    }
  }

  String get statusLabel => status.statusLabel;
  String get priorityLabel => priority.priorityLabel;
}
