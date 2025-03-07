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
      statusIcon = Icons.hourglass_bottom_rounded;
    } else if (daysUntilDue <= 7) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.event_rounded;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Assignment Details Card with enhanced styling
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withOpacity(0.8),
                                statusColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            statusIcon,
                            size: 24,
                            color: Colors.white,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statusColor.withOpacity(0.8),
                                      statusColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Due ${widget.assignment.dueDate.toString().split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: isOverdue ? FontWeight.w500 : null,
                                  ),
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

            // Tasks Section Header with enhanced styling
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.checklist_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: _showAddTaskDialog,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

            // Tasks List with enhanced styling
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
                    return _buildEmptyTasksState();
                  }

                  return ListView(
                    children: [
                      if (pendingTasks.isNotEmpty) ...[
                        _buildTasksSection('Pending', pendingTasks),
                      ],
                      if (completedTasks.isNotEmpty) ...[
                        _buildTasksSection('Completed', completedTasks),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'No tasks yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showAddTaskDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Task'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(String title, List<Task> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: title == 'Pending' 
                  ? Colors.yellow.shade800
                  : Colors.green.shade600,
            ),
          ),
        ),
        ...tasks.map((task) => _buildEnhancedTaskTile(task)),
      ],
    );
  }

  Widget _buildEnhancedTaskTile(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Transform.scale(
            scale: 0.9,
            child: Checkbox(
              value: task.isCompleted,
              onChanged: (value) => _taskService.toggleTaskCompletion(task),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
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
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _taskService.deleteTask(task.id),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}



