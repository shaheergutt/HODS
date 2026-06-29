import 'progress_models.dart';

class ProgressEvent {
  final String taskId;
  final ProgressStage stage;
  final ProgressStatus status;
  final ProgressSeverity severity;
  final String title;
  final String message;
  final String? agentName;
  final double? estimatedProgress;
  final Duration? elapsedTime;
  final DateTime timestamp;

  ProgressEvent({
    required this.taskId,
    required this.stage,
    required this.status,
    this.severity = ProgressSeverity.info,
    required this.title,
    required this.message,
    this.agentName,
    this.estimatedProgress,
    this.elapsedTime,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ProgressEvent(taskId: $taskId, stage: $stage, status: $status, title: $title, message: $message)';
  }
}
