import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'dart:async';


class EmbeddedTasksList extends StatefulWidget {
  final String assignmentId;
  final String userId;
  final TaskService taskService;
  final Function(bool)? onTaskCompleted;

  const EmbeddedTasksList({
    super.key,
    required this.assignmentId,
    required this.userId,
    required this.taskService,
    this.onTaskCompleted,
  });

  @override
  State<EmbeddedTasksList> createState() => _EmbeddedTasksListState();
}

class _EmbeddedTasksListState extends State<EmbeddedTasksList> {
  // Add a map to track task completion status
  final Map<String, bool> _taskCompletionStatus = {};
  // Add subscriptions for task and status changes
  StreamSubscription<List<Task>>? _taskSubscription;
  StreamSubscription<TaskCompletionEvent>? _statusSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Create a fresh subscription with each widget instance
    _taskSubscription = widget.taskService.getTasksForAssignment(widget.assignmentId, widget.userId)
      .listen((tasks) {
        if (mounted) {
          setState(() {
            // Update local task status map 
            for (final task in tasks) {
              _taskCompletionStatus[task.id] = task.isCompleted;
            }
          });
        }
      });
    
    // Listen to the global task status change events
    _statusSubscription = widget.taskService.onTaskStatusChanged.listen((event) {
      if (!mounted) return;
      
      // Handle batch updates (will have taskId 'batch-update')
      if (event.assignmentId == widget.assignmentId && event.taskId == 'batch-update') {
        // Force a full refresh from Firestore
        Future.delayed(const Duration(milliseconds: 50), () async {
          try {
            // Get all tasks for this assignment freshly from Firestore
            final snapshot = await FirebaseFirestore.instance
              .collection('tasks')
              .where('assignmentId', isEqualTo: widget.assignmentId)
              .where('userId', isEqualTo: widget.userId)
              .get();
              
            if (mounted) {
              setState(() {
                // Update local status map with fresh data
                for (final doc in snapshot.docs) {
                  final taskId = doc.id;
                  final isCompleted = doc.data()['isCompleted'] ?? false;
                  _taskCompletionStatus[taskId] = isCompleted;
                }
              });
              
              // Notify parent about task completion status
              if (widget.onTaskCompleted != null) {
                final hasCompletedTasks = _taskCompletionStatus.values.any((isCompleted) => isCompleted);
                widget.onTaskCompleted!(hasCompletedTasks);
              }
            }
          } catch (e) {
            print('Error refreshing task list after batch update: $e');
          }
        });
        return;
      }
      
      // Only care about individual task updates in this assignment
      if (event.assignmentId == widget.assignmentId) {
        // Force Firestore refresh by using a small delay
        Future.delayed(const Duration(milliseconds: 50), () async {
          try {
            // Get fresh task data directly from Firestore
            final doc = await FirebaseFirestore.instance
              .collection('tasks')
              .doc(event.taskId)
              .get();
              
            if (doc.exists) {
              final actualStatus = doc.data()?['isCompleted'] ?? false;
              
              if (mounted) {
                // Update our local state with the verified status
                setState(() {
                  _taskCompletionStatus[event.taskId] = actualStatus;
                });
                
                // Call the callback to notify parent
                if (widget.onTaskCompleted != null) {
                  widget.onTaskCompleted!(_taskCompletionStatus.values.any((isCompleted) => isCompleted));
                }
              }
            }
          } catch (e) {
            print('Error verifying task status: $e');
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _taskSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: widget.taskService.getTasksForAssignment(widget.assignmentId, widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        // Map tasks and override completion status from our local state
        final tasks = snapshot.data!.map((task) {
          // Use our local state if available, otherwise use the task's state
          final isCompleted = _taskCompletionStatus.containsKey(task.id) 
              ? _taskCompletionStatus[task.id]!
              : task.isCompleted;
          
          // Create a new task with the correct completion status
          return task.copyWith(isCompleted: isCompleted);
        }).toList();
        
        final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
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
    final checkmarkColor = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              // Update local state first for immediate feedback
              setState(() {
                _taskCompletionStatus[task.id] = !task.isCompleted;
              });
              
              // Update database after a slight delay
              Future.delayed(const Duration(milliseconds: 100), () {
                widget.taskService.toggleTaskCompletion(task);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
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
                      color: checkmarkColor,
                    )
                  : const SizedBox(),
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
    );
  }
}
