import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/assignment.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import '../services/assignment_service.dart';
//import 'package:animations/animations.dart';
//import '../utils/completion_effects.dart';


class AssignmentDetailsScreen extends StatefulWidget {
  final Assignment assignment;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();
  final AssignmentService _assignmentService = AssignmentService();
  final _taskController = TextEditingController();
  bool _loadingCompletion = false;
  
  // Animation controllers
  late AnimationController _completionAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Map to store task animation controllers
  final Map<String, AnimationController> _taskAnimationControllers = {};
  
  // Keep track of tasks in each category to animate transitions
  List<Task> _lastPendingTasks = [];
  List<Task> _lastCompletedTasks = [];
  bool _needsRebuild = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to task status changes with better timing coordination
    _taskService.onTaskStatusChanged.listen((event) {
      if (mounted) {
        // Don't trigger state changes from here - we'll handle them directly in the task tile
      }
    });
    
    // Setup the animation controller for the completion button
    _completionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _completionAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _taskController.dispose();
    _completionAnimationController.dispose();
    
    // Dispose all task animation controllers
    for (final controller in _taskAnimationControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  // Get or create animation controller for a task
  AnimationController _getAnimationController(String taskId) {
    if (!_taskAnimationControllers.containsKey(taskId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      
      // Add a status listener to ensure smooth transitions
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Wait a frame before allowing any state changes to apply
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // This ensures animations are fully complete before any UI changes
          });
        }
      });
      
      _taskAnimationControllers[taskId] = controller;
    }
    return _taskAnimationControllers[taskId]!;
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
        title: const Text('Assignment Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Intentionally left empty to remove the completion button
        ],
      ),
      body: Stack(
        children: [
          Container(
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
                // Assignment Details Card with enhanced styling and optimistic updates
                _buildAssignmentDetailsCard(statusColor, statusIcon, isOverdue, daysUntilDue, userId),

                // Tasks Section Header
                _buildTasksSectionHeader(),

                // Tasks List with enhanced styling
                _buildTasksList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New method to handle assignment details card with optimistic updates and smooth color transition
  Widget _buildAssignmentDetailsCard(Color statusColor, IconData statusIcon, bool isOverdue, int daysUntilDue, String userId) {
    // Use ValueNotifier for both completion status and animation
    final isCompletedNotifier = ValueNotifier<bool>(widget.assignment.isCompleted);
    final isLoadingNotifier = ValueNotifier<bool>(false);
    
    // Add a ValueNotifier specifically for the background animation
    final cardAnimationNotifier = ValueNotifier<double>(widget.assignment.isCompleted ? 1.0 : 0.0);
    
    // Fetch current status once
    _assignmentService.isAssignmentCompleted(widget.assignment.id, userId)
        .first.then((actualStatus) {
      if (mounted) {
        isCompletedNotifier.value = actualStatus;
        cardAnimationNotifier.value = actualStatus ? 1.0 : 0.0;
      }
    });
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ValueListenableBuilder(
        valueListenable: cardAnimationNotifier,
        builder: (context, animationValue, _) {
          // Interpolate between normal and completed colors based on animation value
          final startGradientColors = [
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ];
          
          final endGradientColors = [
            Colors.green.withOpacity(0.15),  // Original green
            Colors.green.withOpacity(0.05),  // Original lighter green
          ];
          
          final currentGradientColors = [
            Color.lerp(startGradientColors[0], endGradientColors[0], animationValue)!,
            Color.lerp(startGradientColors[1], endGradientColors[1], animationValue)!,
          ];
          
          // Animate border color as well
          final borderColor = Color.lerp(
            Colors.transparent, 
            Colors.green.withOpacity(0.3), // Original green border
            animationValue
          );
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: currentGradientColors,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: borderColor ?? Colors.transparent,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: isCompletedNotifier,
                        builder: (context, isCompleted, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.assignment.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                    : Theme.of(context).colorScheme.onSurface,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.assignment.className,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                    // Completion button with ValueListenableBuilder
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return ValueListenableBuilder(
                          valueListenable: isCompletedNotifier,
                          builder: (context, isCompleted, _) {
                            return ValueListenableBuilder(
                              valueListenable: isLoadingNotifier,
                              builder: (context, isLoading, _) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isCompleted
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: isLoading ? null : () async {
                                          // Set loading state
                                          isLoadingNotifier.value = true;
                                          
                                          // Update local state immediately for responsive UI
                                          final newCompletionState = !isCompleted;
                                          isCompletedNotifier.value = newCompletionState;
                                          
                                          // Animate card background color
                                          if (newCompletionState) {
                                            // Animate to completed state (green)
                                            // Start the animation immediately for a responsive feel
                                            cardAnimationNotifier.value = 0.0; // Reset to ensure animation plays
                                            
                                            // Use a smoother animation with Timer
                                            const totalDuration = 800; // match container duration
                                            const steps = 60; // 60 steps for smooth animation
                                            const stepDuration = totalDuration ~/ steps;
                                            
                                            for (int i = 1; i <= steps; i++) {
                                              if (!mounted) break;
                                              
                                              Future.delayed(Duration(milliseconds: i * stepDuration), () {
                                                if (mounted) {
                                                  cardAnimationNotifier.value = i / steps;
                                                }
                                              });
                                            }
                                            
                                            // Play haptic feedback
                                            HapticFeedback.mediumImpact();
                                            
                                            // Play completion animation
                                            _completionAnimationController.reset();
                                            _completionAnimationController.forward();
                                          } else {
                                            // Animate to uncompleted state (grey)
                                            // Use a smoother animation with Timer
                                            const totalDuration = 800; // match container duration 
                                            const steps = 60; // 60 steps for smooth animation
                                            const stepDuration = totalDuration ~/ steps;
                                            
                                            for (int i = steps; i >= 0; i--) {
                                              if (!mounted) break;
                                              
                                              Future.delayed(Duration(milliseconds: (steps - i) * stepDuration), () {
                                                if (mounted) {
                                                  cardAnimationNotifier.value = i / steps;
                                                }
                                              });
                                            }
                                          }
                                          
                                          try {
                                            // Wait a moment before making database changes
                                            await Future.delayed(const Duration(milliseconds: 50));
                                            
                                            // Update Firebase
                                            await _assignmentService.markAssignmentComplete(
                                              assignmentId: widget.assignment.id,
                                              userId: userId,
                                              complete: newCompletionState,
                                            );
                                          } finally {
                                            if (mounted) {
                                              // Reset loading state
                                              isLoadingNotifier.value = false;
                                            }
                                          }
                                        },
                                        child: RepaintBoundary(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isCompleted
                                                    ? Icons.check_circle_rounded
                                                    : Icons.check_circle_outline_rounded,
                                                  color: isCompleted ? Colors.green : Colors.grey,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isCompleted ? 'Completed' : 'Mark Complete',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: isCompleted ? Colors.green : Colors.grey,
                                                  ),
                                                ),
                                                if (isLoading) ...[
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: isCompleted ? Colors.green : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            );
                          }
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOverdue ? 'Due date passed' : 'Due in $daysUntilDue days',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksSectionHeader() {
    return Padding(
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
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 0.5,
          ),
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
                Icons.check_box_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Tasks',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.25,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddTaskDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return Expanded(
      child: StreamBuilder<List<Task>>(
        stream: _taskService.getTasksForAssignment(
          widget.assignment.id,
          _authService.currentUser!.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];
          
          // Store current tasks for animation tracking
          final pendingTasks = tasks.where((task) => !task.isCompleted).toList();
          final completedTasks = tasks.where((task) => task.isCompleted).toList();
          
          // Store current tasks for next comparison - this prevents flicker by maintaining state
          // Only update these if actual counts changed to prevent needless rebuilds
          if (_lastPendingTasks.length != pendingTasks.length) {
            _lastPendingTasks = List.from(pendingTasks);
          }
          
          if (_lastCompletedTasks.length != completedTasks.length) {
            _lastCompletedTasks = List.from(completedTasks);
          }
          
          if (tasks.isEmpty) {
            return _buildEmptyTasksState();
          }

          // Use RepaintBoundary to minimize repaints
          return RepaintBoundary(
            child: ListView(
              children: [
                // Always show the Pending section
                _buildTasksSection('Pending', pendingTasks),
                
                // Always show the Completed section
                _buildTasksSection('Completed', completedTasks),
              ],
            ),
          );
        },
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
    final Color sectionColor = title == 'Pending' 
        ? Colors.amber.shade700
        : Colors.green.shade600;
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  sectionColor.withOpacity(0.15),
                  sectionColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sectionColor.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    title == 'Pending' ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: sectionColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sectionColor,
                    letterSpacing: 0.25,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                      key: ValueKey<int>(tasks.length),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sectionColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Use AnimatedList-like effects without actually using AnimatedList
        AnimatedSize(
          key: ValueKey("${title}Section-${tasks.length}"),
          duration: const Duration(milliseconds: 400), // Match the delay time
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter, // Align from top for better animation
          child: tasks.isEmpty 
            // Show placeholder when empty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No ${title.toLowerCase()} tasks',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              )
            // Otherwise show the tasks
            : Column(
                children: tasks.map((task) {
                  // Wrap each task with a unique key to help Flutter track them properly
                  return KeyedSubtree(
                    key: ValueKey("task-${task.id}-${task.isCompleted ? 'completed' : 'pending'}"),
                    child: _buildEnhancedTaskTile(task),
                  );
                }).toList(),
              ),
        ),
      ],
    );
  }

  // Update the _buildEnhancedTaskTile method to manage task state locally
  Widget _buildEnhancedTaskTile(Task task) {
    // Get animation controller for this task
    final animationController = _getAnimationController(task.id);
    
    // Use a local cached version of the task to prevent UI flickers
    // This avoids retrieving task state during animation
    final cachedTask = Task(
      id: task.id,
      assignmentId: task.assignmentId,
      userId: task.userId,
      title: task.title,
      isCompleted: task.isCompleted,
      createdAt: task.createdAt,
      completedAt: task.completedAt,
    );
    
    // Wrap in animated container with key for proper reconciliation
    return AnimatedOpacity(
      key: ValueKey("task-${task.id}-${task.isCompleted}"),
      duration: const Duration(milliseconds: 200),
      opacity: 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0.5,
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Simple haptic feedback
                  HapticFeedback.selectionClick();
                  
                  // Reset and play animation before state change
                  animationController.reset();
                  animationController.forward();
                  
                  // Store the current state
                  final newCompletionState = !cachedTask.isCompleted;
                  
                  // Only update the database once the animation is well underway
                  Future.delayed(const Duration(milliseconds: 500), () {
                    // Use a local variable to avoid capturing the task from a future rebuild
                    final taskToUpdate = Task(
                      id: cachedTask.id,
                      assignmentId: cachedTask.assignmentId,
                      userId: cachedTask.userId,
                      title: cachedTask.title,
                      isCompleted: newCompletionState,
                      createdAt: cachedTask.createdAt,
                      completedAt: newCompletionState ? DateTime.now() : null,
                    );
                    
                    // Update the database with our local state
                    _taskService.updateTask(taskToUpdate);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: RepaintBoundary(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: AnimatedBuilder(
                          animation: animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: Tween<double>(
                                begin: 1.0,
                                end: task.isCompleted ? 1.1 : 0.9,
                              )
                              .animate(CurvedAnimation(
                                parent: animationController,
                                curve: Curves.easeOut,
                              ))
                              .value,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: task.isCompleted 
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  color: task.isCompleted
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.transparent,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation, 
                                        child: child
                                      ),
                                    );
                                  },
                                  child: task.isCompleted
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.green,
                                        key: ValueKey('completed'),
                                      )
                                    : const SizedBox(key: ValueKey('uncompleted')),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    title: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      child: Text(task.title),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () => _taskService.deleteTask(task.id),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 24,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



