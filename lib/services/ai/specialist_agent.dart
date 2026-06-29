import 'ai_types.dart';

abstract class SpecialistAgent {
  AgentCapability get capability;
  
  /// Executes the task objective on the shared execution state.
  Future<AgentResult> execute(AgentTask task, ExecutionState state);
}
