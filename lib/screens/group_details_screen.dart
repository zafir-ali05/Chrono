import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Import for sound effects
import '../models/group.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../utils/date_utils.dart';
import '../services/chat_service.dart';
//import '../models/message.dart';
import 'group_settings_screen.dart'; 
import 'assignment_details_screen.dart';
import '../widgets/embedded_tasks_list.dart';
import '../services/task_service.dart';
//import '../widgets/group_chat_widget.dart';


class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> with TickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  final TextEditingController _messageController = TextEditingController();
  
  // Add section expansion state map like in calendar_screen.dart
  final Map<String, bool> _expandedSections = {
    'Overdue': true,
    'Due Soon': true,
    'Upcoming': true,
  };
  
  // Add animation controllers map
  final Map<String, AnimationController> _animationControllers = {};
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabRotationAnimation;
  final _fabKey = GlobalKey();
  bool _isChatVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.0, 0.8, curve: Curves.easeInCubic),
    ));

    _fabRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize animation controllers for each section
    _initAnimationControllers();
  }
  
  void _initAnimationControllers() {
    // Initialize controllers with default values
    for (final section in ['Overdue', 'Due Soon', 'Upcoming', 'Completed']) {
      final isExpanded = section == 'Completed' 
          ? _expandedSections[section] ?? false  // Default Completed to collapsed
          : _expandedSections[section] ?? true;  // Others expanded by default
          
      _animationControllers[section] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        value: isExpanded ? 1.0 : 0.0,
      );
    }
  }
  
  // Toggle section expansion with animation
  void _toggleSectionExpansion(String title) {
    // Play tap/click sound effect
    HapticFeedback.selectionClick();
    
    final isCurrentlyExpanded = _expandedSections[title] ?? true;
    
    if (isCurrentlyExpanded) {
      _animationControllers[title]?.reverse();
    } else {
      _animationControllers[title]?.forward();
    }
    
    setState(() {
      _expandedSections[title] = !isCurrentlyExpanded;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    
    // Dispose all section animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), // Changed icon to info_outline
            onPressed: _showGroupOptions,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMainContent(),
          // Comment out chat visibility
          // if (_isChatVisible) _buildChatBox(),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Comment out the chat button
          /*
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: FloatingActionButton.small(
              key: _fabKey,
              heroTag: 'chatButton',
              onPressed: _toggleChat,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: RotationTransition(
                turns: _fabRotationAnimation,
                child: const Icon(Icons.close),
              ),
            ),
          ),
          const SizedBox(width: 16),
          */
          FloatingActionButton(
            heroTag: 'addButton',
            onPressed: () => _showAddAssignmentDialog(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return StreamBuilder<List<Assignment>>(
      stream: _assignmentService.getGroupAssignments(widget.group.id).map((assignments) {
        // Deduplicate assignments by ID before displaying
        final uniqueAssignments = <String, Assignment>{};
        for (final assignment in assignments) {
          uniqueAssignments[assignment.id] = assignment;
        }
        
        // Sort by due date (earliest first) after deduplication
        final result = uniqueAssignments.values.toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
        return result;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error);
        }

        final assignments = snapshot.data ?? [];
        
        if (assignments.isEmpty) {
          return _buildEmptyAssignmentsState();
        }

        return _buildAssignmentsList(assignments);
      },
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
  
  Widget _buildEmptyAssignmentsState() {
    // Check if we're in dark mode to adjust styles
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(isDarkMode ? 0.5 : 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(isDarkMode ? 0.7 : 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first assignment using the button below',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(isDarkMode ? 0.8 : 1.0),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showAddAssignmentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Assignment'),
            style: OutlinedButton.styleFrom(
              // For dark mode, add a more visible border
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(isDarkMode ? 0.7 : 0.5),
                width: isDarkMode ? 1.5 : 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAssignmentsList(List<Assignment> assignments) {
    // Group assignments by status
    final overdue = <Assignment>[];
    final dueSoon = <Assignment>[];
    final upcoming = <Assignment>[];
    final completed = <Assignment>[];  // New completed category
    
    final userId = _authService.currentUser?.uid ?? '';
    final now = DateTime.now();
    
    // Use FutureBuilder to batch check completion status first
    return FutureBuilder<List<Assignment>>(
      future: _checkCompletionForAssignments(assignments, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Now assignments have proper isCompleted flags
        final assignmentsWithStatus = snapshot.data!;
        
        // Categorize assignments
        for (final assignment in assignmentsWithStatus) {
          if (assignment.isCompleted) {
            completed.add(assignment);
          } else if (assignment.dueDate.isBefore(now)) {
            overdue.add(assignment);
          } else if (assignment.dueDate.difference(now).inDays <= 3) {
            dueSoon.add(assignment);
          } else {
            upcoming.add(assignment);
          }
        }
        
        // Initialize controller for Completed section if needed
        if (!_animationControllers.containsKey('Completed')) {
          _animationControllers['Completed'] = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 250),
            value: (_expandedSections['Completed'] ?? false) ? 1.0 : 0.0,
          );
          _expandedSections['Completed'] = _expandedSections['Completed'] ?? false;
        }
        
        return ListView(
          padding: const EdgeInsets.only(bottom: 100), // Make room for FABs
          children: [
            if (overdue.isNotEmpty) ...[
              RepaintBoundary(
                child: _GroupSectionWrapper(
                  title: 'Overdue',
                  assignments: overdue,
                  initiallyExpanded: _expandedSections['Overdue'] ?? true,
                  controller: _animationControllers['Overdue']!,
                  icon: Icons.warning_rounded,
                  color: Colors.red,
                  assignmentTileBuilder: (context, assignment) => _buildEnhancedAssignmentTile(context, assignment),
                ),
              ),
            ],
            if (dueSoon.isNotEmpty) ...[
              RepaintBoundary(
                child: _GroupSectionWrapper(
                  title: 'Due Soon',
                  assignments: dueSoon,
                  initiallyExpanded: _expandedSections['Due Soon'] ?? true,
                  controller: _animationControllers['Due Soon']!,
                  icon: Icons.hourglass_bottom_rounded,
                  color: Colors.orange,
                  assignmentTileBuilder: (context, assignment) => _buildEnhancedAssignmentTile(context, assignment),
                ),
              ),
            ],
            if (upcoming.isNotEmpty) ...[
              RepaintBoundary(
                child: _GroupSectionWrapper(
                  title: 'Upcoming',
                  assignments: upcoming,
                  initiallyExpanded: _expandedSections['Upcoming'] ?? true,
                  controller: _animationControllers['Upcoming']!,
                  icon: Icons.event_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  assignmentTileBuilder: (context, assignment) => _buildEnhancedAssignmentTile(context, assignment),
                ),
              ),
            ],
            // Add the completed section
            if (completed.isNotEmpty) ...[
              RepaintBoundary(
                child: _GroupSectionWrapper(
                  title: 'Completed',
                  assignments: completed,
                  initiallyExpanded: _expandedSections['Completed'] ?? false, // Default to collapsed
                  controller: _animationControllers['Completed']!,
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  assignmentTileBuilder: (context, assignment) => _buildEnhancedAssignmentTile(context, assignment),
                ),
              ),
            ],
          ],
        );
      }
    );
  }
  
  // Update the _buildEnhancedAssignmentTile method to include animations
  Widget _buildEnhancedAssignmentTile(BuildContext context, Assignment assignment) {
    final bool isOverdue = assignment.dueDate.isBefore(DateTime.now());
    final int daysUntilDue = assignment.dueDate.difference(DateTime.now()).inDays;
    final userId = _authService.currentUser?.uid ?? '';
    
    // Create animation controller for this item
    final AnimationController animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Add StreamBuilder to track completion status for this specific assignment
    return StreamBuilder<bool>(
      stream: _assignmentService.isAssignmentCompleted(assignment.id, userId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;
        final wasCompleted = assignment.isCompleted;
        
        // Play animation when completion status changes
        if (wasCompleted != isCompleted) {
          animationController.reset();
          animationController.forward();
          
          // Also play haptic feedback
          if (isCompleted) {
            HapticFeedback.mediumImpact();
          }
        }
        
        // Set completion status in the Assignment object for consistency
        assignment.isCompleted = isCompleted;
    
        // Enhanced status indicators with gradients
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
          statusColor = Colors.teal;
          statusIcon = Icons.hourglass_top_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.teal.shade300, Colors.teal.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.hourglass_empty_rounded;
          statusGradient = LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        }
        
        // Create the due date indicator widget
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
                isCompleted ? 'Completed' : getDueInDays(assignment.dueDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
        
        // Check if we're in dark mode
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        // Create animation for completed items
        final Animation<double> scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 1),
        ]).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.easeInOut,
        ));
        
        return AnimatedBuilder(
          animation: scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isCompleted && animationController.isAnimating ? scaleAnimation.value : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  child: child,
                ),
              ),
            );
          },
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
                        Expanded(
                          child: Text(
                            assignment.name,
                            style: TextStyle(
                              fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                              fontSize: 15,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              decorationColor: Colors.black54,
                              color: isCompleted 
                                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) 
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
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
                      child: Text(
                        assignment.className,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted
                              ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                    trailing: Padding(
                      padding: const EdgeInsets.only(top: 0), // Add same top padding as due date indicator
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () => _showEditAssignmentDialog(assignment),
                        splashRadius: 24,
                        padding: EdgeInsets.zero, // Remove default padding
                        constraints: const BoxConstraints(), // Remove default constraints
                        visualDensity: VisualDensity.compact, // Make the button more compact
                      ),
                    ),
                  ),
                ),
              ),
              // Move embedded tasks list higher by reducing padding
              Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 4), // Reduced top padding to 0
                child: EmbeddedTasksList(
                  assignmentId: assignment.id,
                  userId: _authService.currentUser?.uid ?? '',
                  taskService: _taskService,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Additional methods for group and assignment operations
  // ...existing code...

  // Comment out _toggleChat method
  /*
  void _toggleChat() {
    if (_isChatVisible) {
      _animationController.reverse().then((_) {
        if (mounted) setState(() => _isChatVisible = false);
      });
    } else {
      setState(() => _isChatVisible = true);
      _animationController.forward();
    }
  }
  */

  // Comment out _buildChatBox method
  /*
  Widget _buildChatBox() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final chatBoxWidth = screenWidth * 0.92;
    // Set a fixed height that won't be affected by keyboard
    final chatBoxHeight = screenHeight * 0.6;

    // Fixed bottom position that won't change with keyboard
    const bottomPosition = 90.0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            if (_fadeAnimation.value > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleChat,
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
                  ),
                ),
              ),
            
            // Chat box - positioned with fixed bottom distance
            Positioned(
              left: 16,
              bottom: bottomPosition,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Container(
                    width: chatBoxWidth,
                    height: chatBoxHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GroupChatWidget(
                      groupId: widget.group.id,
                      groupName: widget.group.name,
                      onClose: _toggleChat,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  */

  void _showGroupOptions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSettingsScreen(group: widget.group),
      ),
    );
  }

  Future<void> _showEditGroupDialog() async {
    // First check if user is the owner
    final userId = _authService.currentUser?.uid;
    if (userId == null || userId != widget.group.creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the group owner can edit group details')),
      );
      return;
    }

    final nameController = TextEditingController(text: widget.group.name);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _groupService.updateGroup(
                  groupId: widget.group.id,
                  name: nameController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group updated')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _groupService.leaveGroup(
                  widget.group.id,
                  _authService.currentUser!.uid,
                );
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to groups screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully left the group'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAssignmentDialog(BuildContext context) async {
    final classController = TextEditingController();
    final nameController = TextEditingController();
    DateTime? selectedDate;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,  // Prevent accidental dismissal
      builder: (dialogContext) => StatefulBuilder(  // Use dialogContext 
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: classController,
                decoration: const InputDecoration(
                  labelText: 'Class',
                ),
                autofocus: true,  // Focus on this field when dialog opens
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Assignment Name',
                ),
              ),
              const SizedBox(height: 16),
              Text(selectedDate != null 
                ? 'Due: ${selectedDate.toString().split(' ')[0]}'
                : 'No date selected'),
              ElevatedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                child: const Text('Select Due Date'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),  // Use dialogContext
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (classController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty ||
                    selectedDate == null) {
                  // Show validation error directly in dialog
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields and select a due date'),
                    ),
                  );
                  return;
                }

                try {
                  // First close the dialog
                  Navigator.of(dialogContext).pop();
                  
                  // Then create the assignment
                  await _assignmentService.createAssignment(
                    groupId: widget.group.id,
                    className: classController.text.trim(),
                    name: nameController.text.trim(),
                    dueDate: selectedDate!,
                    creatorId: _authService.currentUser?.uid ?? '',  // Null-safe access
                  );
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assignment created successfully'),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAssignmentDialog(Assignment assignment) async {
    final classController = TextEditingController(text: assignment.className);
    final nameController = TextEditingController(text: assignment.name);
    DateTime? selectedDate = assignment.dueDate;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,  // Prevent accidental dismissal
      builder: (dialogContext) => StatefulBuilder(  // Use dialogContext
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Assignment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: classController,
                decoration: const InputDecoration(
                  labelText: 'Class',
                ),
                autofocus: true,  // Focus on this field
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Assignment Name',
                ),
              ),
              const SizedBox(height: 16),
              Text(selectedDate != null 
                ? 'Due: ${selectedDate.toString().split(' ')[0]}'
                : 'No date selected'),
              ElevatedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: const Text('Change Due Date'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),  // Use dialogContext
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (classController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Class name and assignment name cannot be empty'),
                    ),
                  );
                  return;
                }

                try {
                  // First close dialog
                  Navigator.of(dialogContext).pop();
                  
                  // Then update the assignment
                  await _assignmentService.updateAssignment(
                    groupId: widget.group.id,
                    assignmentId: assignment.id,
                    className: classController.text.trim(),
                    name: nameController.text.trim(),
                    dueDate: selectedDate,
                  );
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assignment updated'),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await _showDeleteConfirmation(dialogContext);  // Pass dialogContext
                if (confirmed == true) {
                  // Close dialog first
                  Navigator.of(dialogContext).pop();
                  
                  try {
                    await _assignmentService.deleteAssignment(
                      groupId: widget.group.id,
                      assignmentId: assignment.id,
                    );
                    
                    // Show deletion message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment deleted'),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext parentContext) {  // Accept parent context
    return showDialog<bool>(
      context: parentContext,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Add this method inside the _GroupDetailsScreenState class
  Future<List<Assignment>> _checkCompletionForAssignments(List<Assignment> assignments, String userId) async {
    final result = List<Assignment>.from(assignments);
    
    // Use a batch of futures to check completion status concurrently
    final futures = <Future<void>>[];
    
    for (var i = 0; i < result.length; i++) {
      final assignment = result[i];
      futures.add(_assignmentService.isAssignmentCompleted(assignment.id, userId).first.then((isCompleted) {
        assignment.isCompleted = isCompleted;
      }));
    }
    
    await Future.wait(futures);
    return result;
  }
}

// Add this wrapper widget after the _GroupDetailsScreenState class
class _GroupSectionWrapper extends StatefulWidget {
  final String title;
  final List<Assignment> assignments;
  final bool initiallyExpanded;
  final AnimationController controller;
  final IconData icon;
  final Color color;
  final Function(BuildContext, Assignment) assignmentTileBuilder;
  
  const _GroupSectionWrapper({
    required this.title,
    required this.assignments,
    required this.initiallyExpanded,
    required this.controller,
    required this.icon,
    required this.color,
    required this.assignmentTileBuilder,
  });
  
  @override
  _GroupSectionWrapperState createState() => _GroupSectionWrapperState();
}

class _GroupSectionWrapperState extends State<_GroupSectionWrapper> {
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
    // Post-frame callback for animation control
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
        // Content
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: widget.controller,
            child: Column(
              children: widget.assignments.map<Widget>((assignment) => 
                widget.assignmentTileBuilder(context, assignment)
              ).toList(),
            ),
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: widget.controller.value,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
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
}
