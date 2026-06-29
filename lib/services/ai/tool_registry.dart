import '../../models/user_model.dart';
import 'ai_types.dart';

class ToolRegistry {
  static final List<ToolDefinition> _tools = [
    ToolDefinition(
      name: 'searchHostels',
      category: 'Hostels',
      description: 'Search for hostels based on city, budget limit, target university, room type, or stay type.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'city': {'type': 'string', 'description': 'Name of the city to search in'},
        'budget': {'type': 'number', 'description': 'Maximum budget in PKR'},
        'university': {'type': 'string', 'description': 'Hostels near this university'},
        'roomType': {'type': 'string', 'enum': ['single', 'shared'], 'description': 'Room type preference'},
        'stayType': {'type': 'string', 'enum': ['daily', 'monthly'], 'description': 'Stay duration mode'}
      },
    ),
    ToolDefinition(
      name: 'compareHostels',
      category: 'Hostels',
      description: 'Compare details of multiple hostels side by side regarding price, rating, and location.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'hostelIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'List of hostel document IDs'
        }
      },
    ),
    ToolDefinition(
      name: 'searchNearbyHostels',
      category: 'Hostels',
      description: 'Find hostels close to a specific GPS location coordinate.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'latitude': {'type': 'number', 'description': 'GPS latitude coordinate'},
        'longitude': {'type': 'number', 'description': 'GPS longitude coordinate'}
      },
    ),
    ToolDefinition(
      name: 'getHostelDetails',
      category: 'Hostels',
      description: 'Get room types, pricing details, facilities, and image lists of a specific hostel.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'hostelId': {'type': 'string', 'description': 'The target hostel ID'}
      },
    ),
    ToolDefinition(
      name: 'getBookings',
      category: 'Bookings',
      description: 'View active and previous booking requests.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {},
    ),
    ToolDefinition(
      name: 'createBooking',
      category: 'Bookings',
      description: 'File a room booking request for check-in.',
      allowedRoles: [UserRole.student],
      parameterSchema: {
        'hostelId': {'type': 'string', 'description': 'ID of the hostel'},
        'hostelName': {'type': 'string', 'description': 'Name of the hostel'},
        'roomNumber': {'type': 'string', 'description': 'Room number to book'},
        'bedsBooked': {'type': 'number', 'description': 'Number of beds to book'},
        'totalAmount': {'type': 'number', 'description': 'Price amount in PKR'},
        'checkInDate': {'type': 'string', 'description': 'Check in date string'},
        'checkOutDate': {'type': 'string', 'description': 'Check out date string'}
      },
    ),
    ToolDefinition(
      name: 'cancelBooking',
      category: 'Bookings',
      description: 'Cancel an existing room booking request.',
      allowedRoles: [UserRole.student, UserRole.owner],
      parameterSchema: {
        'bookingId': {'type': 'string', 'description': 'ID of the booking to cancel'}
      },
    ),
    ToolDefinition(
      name: 'trackBooking',
      category: 'Bookings',
      description: 'Lookup status details of a specific booking by ID.',
      allowedRoles: [UserRole.student, UserRole.owner],
      parameterSchema: {
        'bookingId': {'type': 'string', 'description': 'ID of the booking document'}
      },
    ),
    ToolDefinition(
      name: 'getComplaints',
      category: 'Complaints',
      description: 'View list of logged complaints.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {},
    ),
    ToolDefinition(
      name: 'createComplaint',
      category: 'Complaints',
      description: 'File a new complaint about broken facilities, utilities, or maintenance.',
      allowedRoles: [UserRole.student],
      parameterSchema: {
        'hostelId': {'type': 'string', 'description': 'Hostel ID'},
        'hostelName': {'type': 'string', 'description': 'Name of the hostel'},
        'title': {'type': 'string', 'description': 'Complaint summary title'},
        'category': {'type': 'string', 'description': 'Category of issue (e.g. Internet, Mess)'},
        'description': {'type': 'string', 'description': 'Detailed issue text'}
      },
    ),
    ToolDefinition(
      name: 'updateComplaint',
      category: 'Complaints',
      description: 'Update the resolution status of a complaint.',
      allowedRoles: [UserRole.owner, UserRole.admin],
      parameterSchema: {
        'complaintId': {'type': 'string', 'description': 'ID of complaint document'},
        'status': {
          'type': 'string',
          'enum': ['inProgress', 'resolved', 'closed'],
          'description': 'New status using camelCase enum name: inProgress, resolved, or closed'
        }
      },
    ),
    ToolDefinition(
      name: 'findRoommates',
      category: 'Roommates',
      description: 'Retrieve matching roommate options according to clean habits, university, gender, and sleep schedules.',
      allowedRoles: [UserRole.student],
      parameterSchema: {},
    ),
    ToolDefinition(
      name: 'ownerAnalytics',
      category: 'Analytics',
      description: 'Retrieve booking rates, total revenue, and pending complaints summary for a hostel owner.',
      allowedRoles: [UserRole.owner, UserRole.admin],
      parameterSchema: {},
    ),
    ToolDefinition(
      name: 'adminAnalytics',
      category: 'Analytics',
      description: 'Retrieve platform metrics including total users, total hostels, and total bookings.',
      allowedRoles: [UserRole.admin],
      parameterSchema: {},
    ),
    ToolDefinition(
      name: 'searchKnowledge',
      category: 'Knowledge',
      description: 'Search HODS knowledge base documents for guidelines and rules.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'query': {'type': 'string', 'description': 'Knowledge search term query'}
      },
    ),
    ToolDefinition(
      name: 'searchPolicies',
      category: 'Knowledge',
      description: 'Look up daily stays refund, cancellation, mess, or security policies.',
      allowedRoles: [UserRole.student, UserRole.owner, UserRole.admin],
      parameterSchema: {
        'query': {'type': 'string', 'description': 'Policy search query terms'}
      },
    ),
  ];

  static List<ToolDefinition> getRegisteredTools() => List.unmodifiable(_tools);

  static ToolDefinition? getByName(String name) {
    for (final tool in _tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
