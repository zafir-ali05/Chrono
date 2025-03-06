import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class EmbeddedTasksList extends StatelessWidget {
  final String assignmentId;
  final String userId;
  final TaskService taskService;

  const EmbeddedTasksList({
    super.key,
    required this.assignmentId,
    required this.userId,
    required this.taskService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: taskService.getTasksForAssignment(assignmentId, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final pendingTasks = snapshot.data!.where((t) => !t.isCompleted).toList();
        if (pendingTasks.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 72, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pendingTasks.map((task) => _buildTaskItem(context, task)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: task.isCompleted,
              onChanged: (_) => taskService.toggleTaskCompletion(task),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
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
    );
  }
}
