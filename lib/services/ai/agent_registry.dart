import 'ai_types.dart';
import 'specialist_agent.dart';

class AgentRegistry {
  static final Map<AgentCapability, SpecialistAgent> _agents = {};

  /// Registers an agent implementation dynamically.
  static void register(SpecialistAgent agent) {
    _agents[agent.capability] = agent;
  }

  /// Looks up a registered agent for the given capability.
  static SpecialistAgent? getAgent(AgentCapability capability) {
    return _agents[capability];
  }

  /// Lists all registered agents.
  static List<SpecialistAgent> getRegisteredAgents() {
    return _agents.values.toList();
  }
  
  /// Clears registry for testing.
  static void clear() {
    _agents.clear();
  }
}
