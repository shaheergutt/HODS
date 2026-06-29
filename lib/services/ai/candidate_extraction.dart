import 'ai_types.dart';

class CandidateExtraction {
  /// Extracts raw hostel data candidates from the ExecutionState.
  /// It searches both the ToolExecutionHistory and WorkingMemory for any lists of hostels.
  static List<Map<String, dynamic>> extractCandidates(ExecutionState state) {
    final List<Map<String, dynamic>> candidates = [];
    final Set<String> seenIds = {}; // Prevent duplicates

    // 1. Search ToolExecutionHistory (most recent first)
    for (var result in state.toolExecutionHistory.reversed) {
      if (result.success && result.data.containsKey('hostels')) {
        final hostels = result.data['hostels'] as List;
        for (var h in hostels) {
          if (h is Map<String, dynamic>) {
            final id = h['id']?.toString() ?? h['hostelId']?.toString();
            if (id != null && !seenIds.contains(id)) {
              seenIds.add(id);
              candidates.add(h);
            }
          }
        }
      }
    }

    // 2. Search WorkingMemory for facts containing hostel lists
    for (var key in state.workingMemory.facts.keys) {
      final value = state.workingMemory.facts[key];
      if (value is List) {
        for (var h in value) {
          if (h is Map<String, dynamic> && (h.containsKey('id') || h.containsKey('hostelId'))) {
            final id = h['id']?.toString() ?? h['hostelId']?.toString();
            if (id != null && !seenIds.contains(id)) {
              seenIds.add(id);
              candidates.add(h);
            }
          }
        }
      }
    }

    return candidates;
  }
}
