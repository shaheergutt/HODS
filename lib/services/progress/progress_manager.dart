import 'dart:async';
import 'progress_models.dart';
import 'progress_event.dart';

class ProgressManager {
  final _controller = StreamController<ProgressEvent>.broadcast();

  /// Broadcast stream of progress events.
  Stream<ProgressEvent> get stream => _controller.stream;

  /// Emits a progress update event.
  void emit(ProgressEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Helper to complete a task stage.
  void complete(String taskId, {ProgressStage? stage, String? message}) {
    emit(ProgressEvent(
      taskId: taskId,
      stage: stage ?? ProgressStage.completed,
      status: ProgressStatus.completed,
      severity: ProgressSeverity.success,
      title: 'Completed',
      message: message ?? 'Finished successfully',
      timestamp: DateTime.now(),
    ));
  }

  /// Closes the controller stream.
  void dispose() {
    _controller.close();
  }
}
