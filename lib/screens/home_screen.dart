import 'package:flutter/material.dart';
import '../models/assignment.dart';
import 'package:flutter/services.dart'; // Import for sound effects
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../services/group_service.dart'; 
import 'assignment_details_screen.dart';
import '../widgets/embedded_tasks_list.dart';
import '../services/task_service.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final TaskService _taskService = TaskService();
  DateTime _focusedDay = DateTime.now();
  
  // Stats for widgets
  int _totalAssignments = 0;
  int _completedAssignments = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  List<Assignment> _upcomingAssignments = [];
  
  // Track completion status for assignments
  final Map<String, bool> _assignmentCompletionStatus = {};
    
  // Store section expansion state
  final Map<String, bool> _expandedSections = {
    'Overdue': true,
    'Due Soon': true,
    'This Week': true,
    'Later': true,
  };
  
  // Store controllers for animations
  final Map<String, AnimationController> _animationControllers = {};

  // Add this map declaration to store group names
  final Map<String, String> _groupNameCache = {};

  // Modified method to dismiss keyboard only when it's actually showing
  void _dismissKeyboard() {
    final FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  @override
  void initState() {
    super.initState();

    // Add route observer to refresh data when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // When returning to this screen, refresh the task stats
      if (ModalRoute.of(context)?.isCurrent == true) {
        _fetchTaskStats();
      }
    });
    
    // clearTaskCache(); // Cleared Cache to fix total tasks bug
    
    // Initialize controllers with optimized settings - add 'Completed' to the list
    for (final section in ['Overdue', 'Due Soon', 'This Week', 'Later', 'Completed']) {
      final isExpanded = _expandedSections[section] ?? (section != 'Completed'); // Default all true except Completed
      _animationControllers[section] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250), // Slightly faster for better perceived performance
        value: isExpanded ? 1.0 : 0.0,
      );
    }
    
    // Fetch group names when assignments are loaded
    if (_authService.currentUser != null) {
      _assignmentService.getUserAssignments(_authService.currentUser!.uid)
        .listen((assignments) {
          for (var assignment in assignments) {
            _fetchGroupName(assignment.groupId);
          }
        });
    }
    
    // Fetch stats for widgets
    _fetchStats();
    
    // Listen for task status change events and update stats accordingly
    _taskService.onTaskStatusChanged.listen((event) {
      _fetchTaskStats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if this route is current (visible) and refresh data
    if (ModalRoute.of(context)?.isCurrent == true) {
      _fetchTaskStats();
      
      // Also refresh assignment completion status
      if (_authService.currentUser != null) {
        final userId = _authService.currentUser!.uid;
        
        for (final assignmentId in _assignmentCompletionStatus.keys) {
          _checkAssignmentCompletionStatus(assignmentId, userId);
        }
      }
    }
  }

  // Fetch stats for the widgets
  void _fetchStats() {
    if (_authService.currentUser != null) {
      final userId = _authService.currentUser!.uid;
      
      // Get assignment stats
      _assignmentService.getAllUserAssignments(userId)
        .listen((assignments) {
          if (mounted) {
            setState(() {
              _totalAssignments = assignments.length;
              _upcomingAssignments = assignments
                  .where((a) => !a.dueDate.isBefore(DateTime.now()))
                  .toList()
                  ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              
              // Track each assignment and listen for its completion status
              for (final assignment in assignments) {
                _checkAssignmentCompletionStatus(assignment.id, userId);
              }
            });
          }
        });
      
      // Get task stats
      _taskService.getUserTasks(userId)
        .listen((tasks) {
          if (mounted) {
            setState(() {
              _totalTasks = tasks.length;
              _completedTasks = tasks
                  .where((t) => t.isCompleted)
                  .length;
            });
          }
        });
    }
  }
  
  // New method to fetch only task stats
  void _fetchTaskStats() {
    if (_authService.currentUser != null) {
      final userId = _authService.currentUser!.uid;
      
      // Get task stats
      _taskService.getUserTasks(userId)
        .listen((tasks) {
          if (mounted) {
            final prevCompletedTasks = _completedTasks;
            final newCompletedTasks = tasks.where((t) => t.isCompleted).length;
            
            setState(() {
              _totalTasks = tasks.length;
              _completedTasks = newCompletedTasks;
            });
            
            // Debug print to verify refresh
            if (prevCompletedTasks != newCompletedTasks) {
              print('Task completion count updated: $prevCompletedTasks → $newCompletedTasks');
            }
          }
        });
    }
  }
  
  // Check completion status for each assignment separately
  void _checkAssignmentCompletionStatus(String assignmentId, String userId) {
    _assignmentService.isAssignmentCompleted(assignmentId, userId).listen((isCompleted) {
      if (mounted) {
        setState(() {
          _assignmentCompletionStatus[assignmentId] = isCompleted;
          
          // Update the completed assignments count based on the current status map
          _completedAssignments = _assignmentCompletionStatus.values
              .where((status) => status)
              .length;
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

  List<Assignment> _filterAssignments(List<Assignment> assignments) {
    return assignments;
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your assignments'),
      );
    }
    
    return GestureDetector(
      // Dismiss keyboard when tapping outside of search field
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent, // Allow taps to pass through to children
      child: Container(
        // Add subtle gradient background to entire screen
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
        child: StreamBuilder<List<Assignment>>(
          stream: _assignmentService.getAllUserAssignments(user.uid),
          builder: (context, snapshot) {
            // Group assignments by timeframe ahead of time
            List<Assignment> overdue = [];
            List<Assignment> dueSoon = [];
            List<Assignment> upcoming = [];
            List<Assignment> later = [];
            List<Assignment> completed = [];
            bool isLoading = snapshot.connectionState == ConnectionState.waiting;
            
            if (!isLoading && snapshot.hasData) {
              final assignments = snapshot.data ?? [];
              final filteredAssignments = _filterAssignments(assignments);
              
              final now = DateTime.now();
              for (final assignment in filteredAssignments) {
                if (_assignmentCompletionStatus[assignment.id] == true) {
                  completed.add(assignment);
                  continue;
                }
                
                if (assignment.dueDate.isBefore(now)) {
                  overdue.add(assignment);
                } else if (assignment.dueDate.difference(now).inDays <= 3) {
                  dueSoon.add(assignment);
                } else if (assignment.dueDate.difference(now).inDays <= 7) {
                  upcoming.add(assignment);
                } else {
                  later.add(assignment);
                }
              }
            }

            return CustomScrollView(
              slivers: [
                // App Bar section
                SliverToBoxAdapter(
                  child: Padding(
                    // Reduce top padding from 48 to 24 to lower the header
                    padding: const EdgeInsets.fromLTRB(24, 72, 16, 8),
                    child: Row(
                      children: [
                        // Greeting text column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${user.displayName?.split(' ')[0] ?? 'there'}! 👋',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Stay on track, don't miss a deadline! 🚀",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile FAB with Transform.translate
                        Transform.translate(
                          offset: const Offset(0, -10), // Move up by 4 pixels
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProfileScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    Theme.of(context).colorScheme.primary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: user.photoURL != null
                                    ? CachedNetworkImage(
                                        imageUrl: user.photoURL!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: Text(
                                            user.displayName?.isNotEmpty == true
                                                ? user.displayName![0].toUpperCase()
                                                : user.email?[0].toUpperCase() ?? '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            user.displayName?.isNotEmpty == true
                                                ? user.displayName![0].toUpperCase()
                                                : user.email?[0].toUpperCase() ?? '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          user.displayName?.isNotEmpty == true
                                              ? user.displayName![0].toUpperCase()
                                              : user.email?[0].toUpperCase() ?? '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Widgets section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _buildWidgetsGrid(context),
                  ),
                ),
                
                // Loading indicator or error
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    child: _buildErrorWidget(snapshot.error),
                  )
                else if ((snapshot.data ?? []).isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else ...[
                  // Assignment sections
                  if (overdue.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _SectionWrapper(
                          title: 'Overdue',
                          assignments: overdue,
                          initiallyExpanded: _expandedSections['Overdue'] ?? true,
                          controller: _animationControllers['Overdue']!,
                          icon: Icons.warning_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                  if (dueSoon.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _SectionWrapper(
                          title: 'Due Soon',
                          assignments: dueSoon,
                          initiallyExpanded: _expandedSections['Due Soon'] ?? true,
                          controller: _animationControllers['Due Soon']!,
                          icon: Icons.hourglass_top_rounded,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _SectionWrapper(
                          title: 'This Week',
                          assignments: upcoming,
                          initiallyExpanded: _expandedSections['This Week'] ?? true,
                          controller: _animationControllers['This Week']!,
                          icon: Icons.event_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  if (later.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _SectionWrapper(
                          title: 'Later',
                          assignments: later,
                          initiallyExpanded: _expandedSections['Later'] ?? true,
                          controller: _animationControllers['Later']!,
                          icon: Icons.calendar_month_rounded,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                  if (completed.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _SectionWrapper(
                          title: 'Completed',
                          assignments: completed,
                          initiallyExpanded: _expandedSections['Completed'] ?? false,
                          controller: _animationControllers['Completed']!,
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                  // Add bottom padding for navigation bar
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100),
                    sliver: SliverToBoxAdapter(child: Container()),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            'Could not load assignments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString() ?? 'Unknown error',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join a group to start tracking assignments',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsListView(
    BuildContext context, {
    required List<Assignment> overdue,
    required List<Assignment> dueSoon,
    required List<Assignment> upcoming,
    required List<Assignment> later,
  }) {
    // Get completed assignments across all categories
    final completed = <Assignment>[];
    
    // Check completion status for each assignment
    if (_authService.currentUser != null) {
      final userId = _authService.currentUser!.uid;
      // Find assignments with true completion status
      for (final entry in _assignmentCompletionStatus.entries) {
        if (entry.value == true) {
          // Find the corresponding assignment object from all categories
          final assignmentId = entry.key;
          final allAssignments = [...overdue, ...dueSoon, ...upcoming, ...later];
          Assignment? foundAssignment;
          for (final a in allAssignments) {
            if (a.id == assignmentId) {
              foundAssignment = a;
              break;
            }
          }
          
          if (foundAssignment != null) {
            completed.add(foundAssignment);
          }
        }
      }
    }
    
    // Now remove completed assignments from other categories
    overdue.removeWhere((assignment) => completed.any((a) => a.id == assignment.id));
    dueSoon.removeWhere((assignment) => completed.any((a) => a.id == assignment.id));
    upcoming.removeWhere((assignment) => completed.any((a) => a.id == assignment.id));
    later.removeWhere((assignment) => completed.any((a) => a.id == assignment.id));
    
    // Initialize controller for the Completed section if it doesn't exist
    if (!_animationControllers.containsKey('Completed')) {
      final isExpanded = _expandedSections['Completed'] ?? false; // Default to collapsed
      _animationControllers['Completed'] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        value: isExpanded ? 1.0 : 0.0,
      );
      _expandedSections['Completed'] = isExpanded;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100), // Extra padding at bottom to account for nav bar
      children: [
        // Add redesigned section headers and assignment tiles
        if (overdue.isNotEmpty) ...[
          RepaintBoundary(
            child: _SectionWrapper(
              title: 'Overdue',
              assignments: overdue,
              initiallyExpanded: _expandedSections['Overdue'] ?? true,
              controller: _animationControllers['Overdue']!,
              icon: Icons.warning_rounded, // Using rounded icons
              color: Colors.red,
            ),
          ),
        ],
        if (dueSoon.isNotEmpty) ...[
          RepaintBoundary(
            child: _SectionWrapper(
              title: 'Due Soon',
              assignments: dueSoon,
              initiallyExpanded: _expandedSections['Due Soon'] ?? true,
              controller: _animationControllers['Due Soon']!,
              icon: Icons.hourglass_top_rounded, // Using rounded icons
              color: Colors.orange,
            ),
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          RepaintBoundary(
            child: _SectionWrapper(
              title: 'This Week',
              assignments: upcoming,
              initiallyExpanded: _expandedSections['This Week'] ?? true,
              controller: _animationControllers['This Week']!,
              icon: Icons.event_rounded, // Using rounded icons
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        if (later.isNotEmpty) ...[
          RepaintBoundary(
            child: _SectionWrapper(
              title: 'Later',
              assignments: later,
              initiallyExpanded: _expandedSections['Later'] ?? true,
              controller: _animationControllers['Later']!,
              icon: Icons.calendar_month_rounded, // Using rounded icons
              color: Colors.grey,
            ),
          ),
        ],
        
        // New "Completed" section
        if (completed.isNotEmpty) ...[
          RepaintBoundary(
            child: _SectionWrapper(
              title: 'Completed',
              assignments: completed,
              initiallyExpanded: _expandedSections['Completed'] ?? false, // Default to collapsed
              controller: _animationControllers['Completed']!,
              icon: Icons.check_circle_rounded,
              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  // New method to build the widgets grid
  Widget _buildWidgetsGrid(BuildContext context) {
    return Column(
      children: [
        // Assignment Progress Widget (full width)
        _buildAssignmentProgressWidget(context),
        const SizedBox(height: 12),
        
        // Row with two square widgets
        Row(
          children: [
            // Tasks Completed Widget
            Expanded(child: _buildTasksCompletedWidget(context)),
            const SizedBox(width: 12),
            // Replace calendar widget with nearest assignment countdown widget
            Expanded(child: _buildNextAssignmentCountdownWidget(context)),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentProgressWidget(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final double progress = _totalAssignments > 0 
      ? _completedAssignments / _totalAssignments 
      : 0.0;
  
  return GestureDetector(
    onTap: () {
      // Maybe show more details or navigate somewhere
      HapticFeedback.lightImpact();
    },
    child: Container(
      // Increase fixed height to better match other widgets
      height: 115, // Changed from 95 to 115
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(isDarkMode ? 0.3 : 0.15),
            Theme.of(context).colorScheme.primary.withOpacity(isDarkMode ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: isDarkMode
            ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16), // Increased padding back to 16 from 12
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget title
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Assignment Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Increased from 8 to 12
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 10, // Increased back from 8 to 10 for better visibility
            ),
          ),
          const SizedBox(height: 10), // Increased from 6 to 10
          // Stats text - use a more compact layout with Row instead of separate Text widgets
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_completedAssignments of $_totalAssignments completed',
                style: TextStyle(
                  fontSize: 13, // Increased from 12 to 13
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(_totalAssignments - _completedAssignments)} remaining',
                style: TextStyle(
                  fontSize: 13, // Increased from 12 to 13
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTasksCompletedWidget(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.secondary.withOpacity(isDarkMode ? 0.3 : 0.15),
              Theme.of(context).colorScheme.secondary.withOpacity(isDarkMode ? 0.1 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: isDarkMode
              ? Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget title
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Centered task count
            Center(
              child: Column(
                children: [
                  Text(
                    '$_completedTasks',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Total tasks at bottom
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalTasks total tasks',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextAssignmentCountdownWidget(BuildContext context) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final now = DateTime.now();
  
  // Find the next upcoming assignment
  Assignment? nextAssignment = _upcomingAssignments.isNotEmpty 
      ? _upcomingAssignments.first 
      : null;
  
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      if (nextAssignment != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentDetailsScreen(assignment: nextAssignment),
          ),
        );
      } else {
        // If no upcoming assignment, navigate to calendar
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const CalendarScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    },
    child: Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.tertiary.withOpacity(isDarkMode ? 0.3 : 0.15),
            Theme.of(context).colorScheme.tertiary.withOpacity(isDarkMode ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: isDarkMode
            ? Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // Reduced vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween instead of Spacer
        children: [
          // Widget title
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Next Due',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          
          // Content in the middle - with constraints to prevent overflow
          Expanded(
            child: Center(
              child: nextAssignment != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assignment name
                        Text(
                          nextAssignment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Class name
                        Text(
                          nextAssignment.className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Countdown
                        Row(
                          children: [
                            Icon(
                              _getCountdownIcon(nextAssignment.dueDate),
                              size: 16,
                              color: _getCountdownColor(nextAssignment.dueDate),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getCountdownText(nextAssignment.dueDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _getCountdownColor(nextAssignment.dueDate),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No upcoming\nassignments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          // View button at bottom - even more compact
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // Further reduced vertical padding
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nextAssignment != null ? 'View details' : 'View calendar',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper methods for countdown widget
IconData _getCountdownIcon(DateTime dueDate) {
  final now = DateTime.now();
  final daysLeft = dueDate.difference(now).inDays;
  
  if (dueDate.isBefore(now)) {
    return Icons.warning_rounded;
  } else if (daysLeft == 0) {
    return Icons.access_time_filled_rounded;
  } else if (daysLeft <= 1) {
    return Icons.hourglass_bottom_rounded;
  } else if (daysLeft <= 3) {
    return Icons.hourglass_top_rounded;
  } else {
    return Icons.calendar_today_rounded;
  }
}

Color _getCountdownColor(DateTime dueDate) {
  final now = DateTime.now();
  final daysLeft = dueDate.difference(now).inDays;
  
  if (dueDate.isBefore(now)) {
    return Colors.red;
  } else if (daysLeft == 0) {
    return Colors.deepOrange;
  } else if (daysLeft <= 1) {
    return Colors.orange;
  } else if (daysLeft <= 3) {
    return Colors.amber;
  } else {
    return Colors.green;
  }
}

String _getCountdownText(DateTime dueDate) {
  final now = DateTime.now();
  
  if (dueDate.isBefore(now)) {
    final overdueDays = now.difference(dueDate).inDays;
    return overdueDays == 0 
        ? 'Due today (overdue)' 
        : 'Overdue by $overdueDays ${overdueDays == 1 ? 'day' : 'days'}';
  }
  
  // Calculate days, hours and minutes remaining
  final difference = dueDate.difference(now);
  final days = difference.inDays;
  final hours = difference.inHours % 24;
  final minutes = difference.inMinutes % 60;
  
  if (days > 0) {
    return 'Due in $days ${days == 1 ? 'day' : 'days'}';
  } else if (hours > 0) {
    return 'Due in $hours ${hours == 1 ? 'hour' : 'hours'}';
  } else {
    return 'Due in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }
}

  // New method to build animated assignments list with pre-built content
  Widget _buildAnimatedAssignmentsList(String sectionTitle, List<Assignment> assignments) {
  // Check if the controller exists, if not create it
  if (!_animationControllers.containsKey(sectionTitle)) {
    final isExpanded = _expandedSections[sectionTitle] ?? true;
    _animationControllers[sectionTitle] = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: isExpanded ? 1.0 : 0.0,
    );
    _expandedSections[sectionTitle] = isExpanded;
  }
  
  final controller = _animationControllers[sectionTitle]!;
  final isExpanded = _expandedSections[sectionTitle] ?? true;
  
  // Move animation triggers outside the build cycle using post-frame callback
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (controller.isAnimating) return; // Skip if already animating
    
    if (isExpanded && controller.value != 1.0) {
      controller.forward();
    } else if (!isExpanded && controller.value != 0.0) {
      controller.reverse();
    }
  });
  
  // Pre-build content to avoid rebuilding during animation
  final Widget content = Column(
    children: assignments.map((assignment) => _buildAssignmentTile(context, assignment)).toList(),
  );
  
  return RepaintBoundary(
    key: ValueKey('section_$sectionTitle'),
    child: AnimatedBuilder(
      animation: controller,
      // Use ClipRect with a constant child to prevent repainting content
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: controller.value,
            child: child,
          ),
        );
      },
      child: content, // Pre-built content passed here
    ),
  );
}

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isExpanded = _expandedSections[title] ?? true;
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () {
              // Use separate method for toggle
              _toggleSectionExpansion(title);
            },
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(isDarkMode ? 0.25 : 0.15),
                    color.withOpacity(isDarkMode ? 0.15 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: isDarkMode
                    ? Border.all(
                        color: color.withOpacity(0.3),
                        width: 0.5,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count ${count == 1 ? 'item' : 'items'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Wrap the _buildAssignmentTile with a memoization function
  Widget _buildAssignmentTile(BuildContext context, Assignment assignment) {
    // Move variable declarations before any widget construction
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    final userId = _authService.currentUser?.uid ?? '';
    
    // Create a local animation controller for this tile
    final AnimationController animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Add StreamBuilder to track completion status for this specific assignment
    return StreamBuilder<bool>(
      stream: _assignmentService.isAssignmentCompleted(assignment.id, userId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;
        
        // Set completion status in the Assignment object for consistency
        final bool statusChanged = assignment.isCompleted != isCompleted;
        if (statusChanged) {
          // Don't trigger a global rebuild when completion status changes
          assignment.isCompleted = isCompleted;
          
          if (statusChanged && isCompleted) {
            animationController.reset();
            animationController.forward();
            
            // Also play haptic feedback
            HapticFeedback.mediumImpact();
          }
        }
        
        // Status indicators with updated styling
        final Color statusColor;
        final IconData statusIcon;
        final LinearGradient statusGradient;
        
        if (isCompleted) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.green.shade300, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else if (isOverdue) {
          statusColor = Colors.red;
          statusIcon = Icons.warning_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.red.shade300, Colors.red.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else if (daysUntilDue <= 3) {
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_bottom_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.orange.shade300, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else if (daysUntilDue <= 7) {
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_top_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.orange.shade300, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.hourglass_empty_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        }

        // Create title and className widgets here
        Widget titleWidget;
        Widget classNameWidget;
        
        titleWidget = Text(
          assignment.name,
          style: TextStyle(
            fontWeight: isOverdue ? FontWeight.w500 : FontWeight.normal,
            fontSize: 15,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: Colors.black54,
            color: isCompleted 
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) 
                : Theme.of(context).colorScheme.onSurface,
          ),
        );
        classNameWidget = Text(
          assignment.className,
          style: TextStyle(
            fontSize: 13,
            color: isCompleted 
                ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
        
        // Due date indicator widget
        Widget dueDateIndicator = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: statusGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusIcon,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted ? 'Completed' : app_date_utils.getDueInDays(assignment.dueDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
        
        // Determine if we're in dark mode
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        // Create smooth animation for tile
        final Animation<double> scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
        ]).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.easeInOut,
        ));
        
        // Now build and return the widget tree
        return RepaintBoundary(
          key: ValueKey('${assignment.id}_${isCompleted ? 'completed' : 'pending'}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ScaleTransition(
              scale: scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Adjust background color based on theme brightness
                  color: isDarkMode 
                      ? Theme.of(context).colorScheme.surface.withOpacity(1.0)  // Full opacity in dark mode
                      : Theme.of(context).colorScheme.surface,
                  // Enhance shadow for dark mode
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)   // Darker shadow for dark mode
                          : Colors.black.withOpacity(0.05),
                      blurRadius: isDarkMode ? 12 : 10,
                      offset: const Offset(0, 2),
                      spreadRadius: isDarkMode ? 1 : 0,     // Add spread in dark mode
                    ),
                    // Add a subtle glow effect in dark mode for better visibility
                    if (isDarkMode) BoxShadow(
                      color: statusColor.withOpacity(0.15),  // Colored glow based on status
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                      spreadRadius: 0,
                    ),
                  ],
                  // Add subtle border for dark mode
                  border: isDarkMode
                      ? Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 0.5,
                        )
                      : null,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssignmentDetailsScreen(assignment: assignment),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                            children: [
                              // Assignment name on the left
                              Expanded(child: titleWidget),
                              // Due date indicator on the right with some top padding
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2), // Add 2px of top padding
                                child: dueDateIndicator,
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2), // Reduced top padding from 4 to 2
                            child: classNameWidget,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: statusGradient,
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
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Move embedded tasks list higher by reducing padding
                    Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 12),
                      child: RepaintBoundary(
                        child: EmbeddedTasksList(
                          assignmentId: assignment.id,
                          userId: _authService.currentUser?.uid ?? '',
                          taskService: _taskService,
                          onTaskCompleted: (isCompleted) {
                            // Never trigger state changes from here to avoid flickering
                            // Use isolatedUpdate pattern to prevent UI tree rebuilds
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              // Intentionally empty - let the streams handle updates
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGroupNameFromId(String groupId) {
    return _groupNameCache[groupId] ?? 'Loading...';
  }

  // Add this method to fetch and cache group names
  Future<void> _fetchGroupName(String groupId) async {
    if (_groupNameCache.containsKey(groupId)) return;
    
    try {
      final groupName = await _groupService.getGroupName(groupId);
      if (mounted) {
        setState(() {
          _groupNameCache[groupId] = groupName;
        });
      }
    } catch (e) {
      print('Error fetching group name: $e');
      if (mounted) {
        setState(() {
          _groupNameCache[groupId] = 'Error';
        });
      }
    }
  }

  // Replace your current _toggleSectionExpansion with this optimized version
void _toggleSectionExpansion(String title) {
  // Play tap/click sound effect
  HapticFeedback.selectionClick();
  
  // Only update the specific section's state, don't rebuild everything
  final isCurrentlyExpanded = _expandedSections[title] ?? true;
  
  // Move animation outside setState to separate animation from layout rebuilds
  if (isCurrentlyExpanded) {
    _animationControllers[title]?.reverse();
  } else {
    _animationControllers[title]?.forward();
  }
  
  // Delay the actual state update until AFTER animation starts
  Future.microtask(() {
    if (mounted) {
      setState(() {
        // Only update this specific section's state
        _expandedSections[title] = !isCurrentlyExpanded;
      });
    }
  });
}
}

// Create a stateful wrapper widget for each section to isolate rebuilds
class _SectionWrapper extends StatefulWidget {
  final String title;
  final List<Assignment> assignments;
  final bool initiallyExpanded;
  final AnimationController controller;
  final IconData icon;
  final Color color;
  
  const _SectionWrapper({
    required this.title,
    required this.assignments,
    required this.initiallyExpanded,
    required this.controller,
    required this.icon,
    required this.color,
  });

  @override
  _SectionWrapperState createState() => _SectionWrapperState();
}

class _SectionWrapperState extends State<_SectionWrapper> {
  late bool _isExpanded;
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    
    // Initialize controller immediately to match expected state
    if (_isExpanded && widget.controller.value == 0.0) {
      widget.controller.value = 1.0;
    } else if (!_isExpanded && widget.controller.value == 1.0) {
      widget.controller.value = 0.0;
    }
    
    // Listen to controller to update local state without triggering parent rebuilds
    widget.controller.addStatusListener(_handleStatusChange);
  }
  
  @override
  void dispose() {
    widget.controller.removeStatusListener(_handleStatusChange);
    super.dispose();
  }
  
  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _isExpanded) {
      setState(() => _isExpanded = false);
    } else if (status == AnimationStatus.completed && !_isExpanded) {
      setState(() => _isExpanded = true);
    }
  }
  
  void _toggleExpansion() {
    // Skip if already animating
    if (widget.controller.isAnimating) return;
    
    // Add haptic feedback and sound effect
    HapticFeedback.selectionClick();
    
    if (_isExpanded) {
      widget.controller.reverse();
    } else {
      widget.controller.forward();
    }
    
    // Update state only after animation starts
    Future.microtask(() {
      if (mounted) {
        setState(() => _isExpanded = !_isExpanded);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Post-frame callback for animation control - just like calendar screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.isAnimating) return; // Skip if already animating
      
      if (_isExpanded && widget.controller.status != AnimationStatus.completed && 
          widget.controller.status != AnimationStatus.forward) {
        widget.controller.forward();
      } else if (!_isExpanded && widget.controller.status != AnimationStatus.dismissed && 
                widget.controller.status != AnimationStatus.reverse) {
        widget.controller.reverse();
      }
    });
    
    return Column(
      children: [
        // Header
        GestureDetector(
          onTap: _toggleExpansion,
          child: _buildHeader(context),
        ),
        // This is the key fix: Completely isolate the assignment tiles from the section animation
        RepaintBoundary( // Add outer boundary
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: widget.controller.value,
                  child: RepaintBoundary( // Add inner boundary
                    child: child!,
                  ),
                ),
              );
            },
            // The major change: Use an IndexedStack to completely preserve state
            child: IndexedStack(
              index: 0, // Always show the assignments
              sizing: StackFit.loose,
              children: [
                Column(
                  children: widget.assignments.map((assignment) => 
                    // Use an independent key that DOESN'T include completion status
                    // This prevents rebuilds when completion status changes
                    KeyedSubtree(
                      key: ValueKey("assignment-${assignment.id}"), // No completion status in key
                      child: _buildAssignmentTile(context, assignment)
                    )
                  ).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Fixed _buildHeader method
  Widget _buildHeader(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(isDarkMode ? 0.25 : 0.15),
                  widget.color.withOpacity(isDarkMode ? 0.15 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: isDarkMode
                  ? Border.all(
                      color: widget.color.withOpacity(0.3),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 14, color: widget.color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                      letterSpacing: 0.25,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.assignments.length} ${widget.assignments.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Fixed assignment tile method
  Widget _buildAssignmentTile(BuildContext context, Assignment assignment) {
    // Here we need to get access to the parent class's method
    // Since we can't directly access it, we need a workaround
    final homeScreen = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeScreen != null) {
      return homeScreen._buildAssignmentTile(context, assignment);
    }
    
    // Fallback in case we can't find the parent
    return ListTile(
      title: Text(assignment.name),
      subtitle: Text(assignment.className),
    );
  }
}
