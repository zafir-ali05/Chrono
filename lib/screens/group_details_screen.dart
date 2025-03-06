import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/group.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../utils/date_utils.dart';
import '../services/chat_service.dart';
import '../models/message.dart';
import 'group_settings_screen.dart'; 
import 'assignment_details_screen.dart';
import '../widgets/embedded_tasks_list.dart';
import '../services/task_service.dart';
import '../widgets/group_chat_widget.dart';


class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> with SingleTickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  final TextEditingController _messageController = TextEditingController();
  
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
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
      stream: _assignmentService.getGroupAssignments(widget.group.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error);
        }

        final assignments = snapshot.data ?? [];
        
        // Sort assignments by due date (earliest first)
        assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
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
            'Add your first assignment using the button below',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showAddAssignmentDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Assignment'),
            style: OutlinedButton.styleFrom(
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
    
    final now = DateTime.now();
    for (final assignment in assignments) {
      if (assignment.dueDate.isBefore(now)) {
        overdue.add(assignment);
      } else if (assignment.dueDate.difference(now).inDays <= 3) {
        dueSoon.add(assignment);
      } else {
        upcoming.add(assignment);
      }
    }
    
    return ListView(
      padding: const EdgeInsets.only(bottom: 100), // Make room for FABs
      children: [
        if (overdue.isNotEmpty) ...[
          _buildEnhancedSectionHeader('Overdue', overdue.length, Colors.red, Icons.warning_rounded),
          ...overdue.map((a) => _buildEnhancedAssignmentTile(a)),
        ],
        if (dueSoon.isNotEmpty) ...[
          _buildEnhancedSectionHeader('Due Soon', dueSoon.length, Colors.orange, Icons.hourglass_bottom_rounded),
          ...dueSoon.map((a) => _buildEnhancedAssignmentTile(a)),
        ],
        if (upcoming.isNotEmpty) ...[
          _buildEnhancedSectionHeader('Upcoming', upcoming.length, Theme.of(context).colorScheme.primary, Icons.event_rounded),
          ...upcoming.map((a) => _buildEnhancedAssignmentTile(a)),
        ],
      ],
    );
  }
  
  Widget _buildEnhancedSectionHeader(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnhancedAssignmentTile(Assignment assignment) {
    final bool isOverdue = assignment.dueDate.isBefore(DateTime.now());
    final int daysUntilDue = assignment.dueDate.difference(DateTime.now()).inDays;
    
    // Enhanced status indicators with gradients
    final Color statusColor;
    final IconData statusIcon;
    final LinearGradient statusGradient;
    
    if (isOverdue) {
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
    } else {
      statusColor = Theme.of(context).colorScheme.primary;
      statusIcon = Icons.event_rounded;
      statusGradient = LinearGradient(
        colors: [
          Theme.of(context).colorScheme.primary.withOpacity(0.7),
          Theme.of(context).colorScheme.primary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
                  title: Text(
                    assignment.name,
                    style: TextStyle(
                      fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.className,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: statusGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
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
                                getDueInDays(assignment.dueDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onPressed: () => _showAssignmentOptions(assignment),
                    splashRadius: 24,
                  ),
                ),
              ),
            ),
            EmbeddedTasksList(
              assignmentId: assignment.id,
              userId: _authService.currentUser?.uid ?? '',
              taskService: _taskService,
            ),
          ],
        ),
      ),
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

  void _showAssignmentOptions(Assignment assignment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Assignment'),
              onTap: () {
                Navigator.pop(context);
                _showEditAssignmentDialog(assignment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Assignment'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed == true) {
                  await _assignmentService.deleteAssignment(
                    groupId: widget.group.id,
                    assignmentId: assignment.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment deleted')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
