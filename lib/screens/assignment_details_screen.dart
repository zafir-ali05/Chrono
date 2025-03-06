import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import 'package:animations/animations.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final Assignment assignment;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();
  final _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: _taskController,
          decoration: const InputDecoration(
            labelText: 'Task Description',
            hintText: 'Enter what needs to be done',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_taskController.text.isNotEmpty) {
                final task = Task(
                  id: '',
                  assignmentId: widget.assignment.id,
                  userId: _authService.currentUser!.uid,
                  title: _taskController.text.trim(),
                  createdAt: DateTime.now(),
                );
                await _taskService.createTask(task);
                _taskController.clear();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return const SizedBox();

    final now = DateTime.now();
    final isOverdue = widget.assignment.dueDate.isBefore(now);
    final daysUntilDue = widget.assignment.dueDate.difference(now).inDays;
    
    final Color statusColor;
    final IconData statusIcon;
    
    if (isOverdue) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (daysUntilDue <= 3) {
      statusColor = Colors.red;
      statusIcon = Icons.hourglass_bottom;
    } else if (daysUntilDue <= 7) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.event;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.name),
        // Removed the actions array containing the edit button
      ),
      body: Column(
        children: [
          // Assignment Details Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Icon(
                          statusIcon,
                          size: 24,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.assignment.className,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Due ${widget.assignment.dueDate.toString().split(' ')[0]}',
                              style: TextStyle(
                                fontSize: 14,
                                color: statusColor,
                                fontWeight: isOverdue ? FontWeight.w500 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tasks Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.checklist, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.25,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _showAddTaskDialog,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Tasks List
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _taskService.getTasksForAssignment(
                widget.assignment.id,
                userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data!;
                final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
                final completedTasks = tasks.where((t) => t.isCompleted).toList();

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showAddTaskDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Task'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  children: [
                    if (pendingTasks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...pendingTasks.map((task) => _buildTaskTile(task)),
                    ],
                    if (completedTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      ...completedTasks.map((task) => _buildTaskTile(task)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _taskService.toggleTaskCompletion(task),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  : null,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _taskService.deleteTask(task.id),
          ),
        ),
      ),
    );
  }
}



