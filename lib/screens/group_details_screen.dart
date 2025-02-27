import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../services/group_service.dart';
import '../utils/date_utils.dart';
import '../services/chat_service.dart';
import '../models/message.dart';

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
  final TextEditingController _messageController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _positionAnimation;
  final GlobalKey _chatButtonKey = GlobalKey();
  bool _isChatVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animation);
    _positionAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animation);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _showEditAssignmentDialog(Assignment assignment) async {
    final classController = TextEditingController(text: assignment.className);
    final nameController = TextEditingController(text: assignment.name);
    DateTime? selectedDate = assignment.dueDate;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _assignmentService.updateAssignment(
                  groupId: widget.group.id,
                  assignmentId: assignment.id,
                  className: classController.text,
                  name: nameController.text,
                  dueDate: selectedDate,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await _showDeleteConfirmation();
                if (confirmed == true && mounted) {
                  await _assignmentService.deleteAssignment(
                    groupId: widget.group.id,
                    assignmentId: assignment.id,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment deleted')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(assignment.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${assignment.className}'),
            Text(
              getDueInDays(assignment.dueDate),
              style: TextStyle(
                color: assignment.dueDate.isBefore(DateTime.now())
                    ? Colors.red
                    : assignment.dueDate.difference(DateTime.now()).inDays <= 3
                        ? Colors.orange
                        : null,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditAssignmentDialog(assignment),
        ),
      ),
    );
  }

  Future<void> _showAddAssignmentDialog(BuildContext context) async {
    final classController = TextEditingController();
    final nameController = TextEditingController();
    DateTime? selectedDate;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (classController.text.isNotEmpty &&
                    nameController.text.isNotEmpty &&
                    selectedDate != null) {
                  try {
                    await _assignmentService.createAssignment(
                      groupId: widget.group.id,
                      className: classController.text,
                      name: nameController.text,
                      dueDate: selectedDate!,
                      creatorId: _authService.currentUser!.uid,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment created successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    print("Error in dialog: $e"); // Debug print
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                        ),
                      );
                    }
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

  Widget _buildChatBox() {
    final screenWidth = MediaQuery.of(context).size.width;
    final chatBoxWidth = screenWidth * 0.9;
    final chatBoxHeight = 400.0;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double scale = _scaleAnimation.value;
        
        return Positioned(
          right: (screenWidth - chatBoxWidth) / 2,
          bottom: 160, // Fixed position above the chat button
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: chatBoxWidth,
                height: chatBoxHeight,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Group Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              _animationController.reverse().then((_) {
                                setState(() => _isChatVisible = false);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<Message>>(
                        stream: _chatService.getMessages(widget.group.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final messages = snapshot.data!;
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe = message.senderId == _authService.currentUser?.uid;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blue : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Text(
                                          message.senderName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMe ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                      Text(
                                        message.content,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _sendMessage,
                          ),
                        ],
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

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendMessage(
        widget.group.id,
        _authService.currentUser!.uid,
        _authService.currentUser!.displayName ?? 'Anonymous',
        _messageController.text.trim(),
      );
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Assignment>>(
            stream: _assignmentService.getGroupAssignments(widget.group.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final assignments = snapshot.data!;
              if (assignments.isEmpty) {
                return const Center(
                  child: Text('No assignments yet'),
                );
              }

              return ListView.builder(
                itemCount: assignments.length,
                itemBuilder: (context, index) => 
                    _buildAssignmentCard(assignments[index]),
              );
            },
          ),
          if (_isChatVisible) _buildChatBox(),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            left: 32,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'leaveButton',
              onPressed: () => _confirmLeaveGroup(context),
              backgroundColor: Colors.red,
              child: const Icon(Icons.exit_to_app),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton(
              key: _chatButtonKey,  // Add this key
              heroTag: 'chatButton',
              onPressed: () {
                setState(() => _isChatVisible = true);
                _animationController.forward();
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.chat),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'addButton',
              onPressed: () => _showAddAssignmentDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
