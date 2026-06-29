import '../../models/user_model.dart';
import 'ai_types.dart';
import 'tool_interface.dart';
import 'tools/hostel_search_tool.dart';
import 'tools/booking_lookup_tool.dart';
import 'tools/complaint_tool.dart';
import 'tools/analytics_tool.dart';
import 'tools/roommate_tool.dart';
import 'tools/knowledge_tool.dart';

class ToolExecutor {
  final Map<String, BaseTool> _toolsMap = {};

  ToolExecutor() {
    final searchTool = HostelSearchTool();
    final bookingTool = BookingLookupTool();
    final complaintTool = ComplaintTool();
    final analyticsTool = AnalyticsTool();
    final roommateTool = RoommateTool();
    final knowledgeTool = KnowledgeTool();

    _toolsMap['searchHostels'] = searchTool;
    _toolsMap['compareHostels'] = searchTool;
    _toolsMap['searchNearbyHostels'] = searchTool;
    _toolsMap['getHostelDetails'] = searchTool;

    _toolsMap['getBookings'] = bookingTool;
    _toolsMap['createBooking'] = bookingTool;
    _toolsMap['cancelBooking'] = bookingTool;
    _toolsMap['trackBooking'] = bookingTool;

    _toolsMap['getComplaints'] = complaintTool;
    _toolsMap['createComplaint'] = complaintTool;
    _toolsMap['updateComplaint'] = complaintTool;

    _toolsMap['findRoommates'] = roommateTool;

    _toolsMap['ownerAnalytics'] = analyticsTool;
    _toolsMap['adminAnalytics'] = analyticsTool;

    _toolsMap['searchKnowledge'] = knowledgeTool;
    _toolsMap['searchPolicies'] = knowledgeTool;
  }

  Future<ToolResult> execute(
    String toolName,
    Map<String, dynamic> arguments,
    String userId,
    UserRole role,
  ) async {
    final startTime = DateTime.now();
    final tool = _toolsMap[toolName];
    if (tool == null) {
      final elapsed = DateTime.now().difference(startTime);
      return ToolResult(
        toolName: toolName,
        success: false,
        data: {},
        error: 'Tool "$toolName" is not registered in Executor.',
        executionTime: elapsed,
        metadata: {},
      );
    }

    final argsWithToolName = Map<String, dynamic>.from(arguments);
    argsWithToolName['toolName'] = toolName;

    return await tool.execute(argsWithToolName, userId, role);
  }
}
