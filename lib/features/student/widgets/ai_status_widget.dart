import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/progress/progress_models.dart';
import '../../../services/progress/progress_event.dart';
import '../../../services/progress/progress_manager.dart';

class AiStatusWidget extends StatefulWidget {
  final ProgressManager progressManager;
  final VoidCallback onCompletionFinished;

  const AiStatusWidget({
    super.key,
    required this.progressManager,
    required this.onCompletionFinished,
  });

  @override
  State<AiStatusWidget> createState() => _AiStatusWidgetState();
}

class _AiStatusWidgetState extends State<AiStatusWidget> with SingleTickerProviderStateMixin {
  late final StreamSubscription<ProgressEvent> _subscription;
  final List<ProgressEvent> _events = [];
  final Map<String, int> _elapsedSeconds = {};
  Timer? _elapsedTimer;
  double _opacity = 1.0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.progressManager.stream.listen(_handleProgressEvent);
    _startElapsedTimer();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        for (final event in _events) {
          if (event.status == ProgressStatus.started || event.status == ProgressStatus.running) {
            _elapsedSeconds[event.taskId] = (_elapsedSeconds[event.taskId] ?? 0) + 1;
          }
        }
      });
    });
  }

  void _handleProgressEvent(ProgressEvent event) {
    if (!mounted) return;
    setState(() {
      // If complete session, trigger completion sequence
      if (event.stage == ProgressStage.completed) {
        _isFinished = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _opacity = 0.0;
          });
          Future.delayed(const Duration(milliseconds: 300), widget.onCompletionFinished);
        });
        return;
      }

      // Check if taskId already exists
      final index = _events.indexWhere((e) => e.taskId == event.taskId);
      if (index >= 0) {
        _events[index] = event;
      } else {
        _events.add(event);
      }

      if (event.status == ProgressStatus.completed || event.status == ProgressStatus.failed) {
        _elapsedSeconds.remove(event.taskId);
      }
    });
  }

  double _calculateEstimatedProgress() {
    if (_events.isEmpty) return 0.0;
    
    // Distinct total stages defined in the flow
    final totalStagesCount = _events.map((e) => e.stage).toSet().length;
    final completedStagesCount = _events
        .where((e) => e.status == ProgressStatus.completed)
        .map((e) => e.stage)
        .toSet()
        .length;

    if (totalStagesCount == 0) return 0.0;
    return (completedStagesCount / totalStagesCount) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return const SizedBox.shrink();
    }

    final double progressPercentage = _calculateEstimatedProgress();

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with status indicator & percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isFinished ? 'Response Ready' : 'AI Collaboration Timeline',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!_isFinished)
                    Text(
                      '${progressPercentage.toInt()}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Horizontal progress bar
              if (!_isFinished)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercentage / 100,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 4,
                  ),
                ),
              if (!_isFinished) const SizedBox(height: 14),

              // Dynamic timeline list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  itemBuilder: (ctx, idx) {
                    final event = _events[idx];
                    return _buildTimelineItem(event);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ProgressEvent event) {
    final bool isCompleted = event.status == ProgressStatus.completed;
    final bool isFailed = event.status == ProgressStatus.failed;
    final bool isRunning = event.status == ProgressStatus.started || event.status == ProgressStatus.running;

    Widget iconWidget;
    Color textColor;
    
    if (isCompleted) {
      iconWidget = const Icon(Icons.check_circle, color: Colors.green, size: 16);
      textColor = AppColors.textSecondary;
    } else if (isFailed) {
      iconWidget = const Icon(Icons.warning, color: AppColors.error, size: 16);
      textColor = AppColors.error;
    } else if (isRunning) {
      iconWidget = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
      textColor = AppColors.textPrimary;
    } else {
      iconWidget = const Icon(Icons.radio_button_unchecked, color: AppColors.textHint, size: 16);
      textColor = AppColors.textHint;
    }

    final seconds = _elapsedSeconds[event.taskId] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: iconWidget,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isRunning && seconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '${(seconds).toStringAsFixed(1)} seconds',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
