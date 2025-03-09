import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'package:flutter/services.dart';
import '../utils/completion_effects.dart';

class EmbeddedTasksList extends StatefulWidget {
  final String assignmentId;
  final String userId;
  final TaskService taskService;
  // Add this callback parameter
  final Function(bool)? onTaskCompleted;

  const EmbeddedTasksList({
    super.key,
    required this.assignmentId,
    required this.userId,
    required this.taskService,
    this.onTaskCompleted, // New parameter
  });

  @override
  State<EmbeddedTasksList> createState() => _EmbeddedTasksListState();
}

class _EmbeddedTasksListState extends State<EmbeddedTasksList> with TickerProviderStateMixin {
  // Map to store animation controllers for each task
  final Map<String, AnimationController> _animationControllers = {};
  
  @override
  void initState() {
    super.initState();
    
    // Listen to task changes by watching the assignment's task list directly
    widget.taskService.getTasksForAssignment(widget.assignmentId, widget.userId)
        .listen((tasks) {
      if (mounted && widget.onTaskCompleted != null) {
        // Whenever the tasks list changes, notify the parent of completion status
        final hasCompletedTask = tasks.any((task) => task.isCompleted);
        widget.onTaskCompleted!(hasCompletedTask);
      }
    });
    
    // Also listen to direct completion events
    widget.taskService.onTaskStatusChanged.listen((event) {
      if (mounted) {
        // We don't need to check the specific task here since the tasks stream
        // above will capture all changes and handle the callback properly
        setState(() {
          // Just trigger a local rebuild
        });
      }
    });
  }
  
  @override
  void dispose() {
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // Get or create an animation controller for a task
  AnimationController _getAnimationController(String taskId) {
    if (!_animationControllers.containsKey(taskId)) {
      _animationControllers[taskId] = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
    }
    return _animationControllers[taskId]!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: widget.taskService.getTasksForAssignment(widget.assignmentId, widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final pendingTasks = snapshot.data!.where((t) => !t.isCompleted).toList();
        if (pendingTasks.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 72, right: 16, top: 0, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pendingTasks.map((task) => _buildTaskItem(context, task)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task) {
    final controller = _getAnimationController(task.id);
    final checkmarkColor = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ClipRect(
        child: CompletionEffects.buildTaskCompletionAnimation(
          controller: controller,
          isCompleted: task.isCompleted,
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  // Play a light haptic feedback
                  CompletionEffects.playTaskCompletionFeedback();
                  
                  // If not already completed, play the animation
                  if (!task.isCompleted) {
                    controller.reset();
                    controller.forward();
                  }
                  
                  // Slight delay before updating the database to allow animation to play
                  Future.delayed(const Duration(milliseconds: 200), () {
                    widget.taskService.toggleTaskCompletion(task);
                    // Call the callback if provided
                    if (widget.onTaskCompleted != null) {
                      widget.onTaskCompleted!(task.isCompleted);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                        width: 1.5,
                      ),
                      color: task.isCompleted 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: task.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : CompletionEffects.buildCheckmarkAnimation(
                          controller: controller,
                          color: checkmarkColor,
                          size: 16,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
