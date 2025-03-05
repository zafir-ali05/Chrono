import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/assignment.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../services/assignment_service.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Group group;
  
  const GroupSettingsScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late final GroupService _groupService;
  late final AuthService _authService;
  late final AssignmentService _assignmentService;

  @override
  void initState() {
    super.initState();
    _groupService = GroupService();
    _authService = AuthService();
    _assignmentService = AssignmentService();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final isOwner = currentUser?.uid == widget.group.creatorId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _groupService.getGroupMembers(widget.group.id),
        builder: (context, memberSnapshot) {
          return StreamBuilder<List<Assignment>>(
            stream: _assignmentService.getGroupAssignments(widget.group.id),
            builder: (context, assignmentSnapshot) {
              if (memberSnapshot.hasError) {
                print('Error loading members: ${memberSnapshot.error}');
                print('Stack trace: ${memberSnapshot.stackTrace}');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading members: ${memberSnapshot.error}'),
                      TextButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final isLoading = memberSnapshot.connectionState == ConnectionState.waiting;
              final members = memberSnapshot.data ?? [];
              final assignmentCount = assignmentSnapshot.data?.length ?? 0;
              
              return ListView(
                children: [
                  // Group Info Card with updated statistics
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.group.name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.group.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Group Code: ${widget.group.id}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          
                          // Statistics - use actual member count from group.members
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatistic(
                                context,
                                Icons.people_outline,
                                isLoading ? '...' : '${widget.group.members.length}',
                                'Members',
                              ),
                              _buildStatistic(
                                context,
                                Icons.assignment_outlined,
                                isLoading ? '...' : '$assignmentCount',
                                'Assignments',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Actions Section
                  if (isOwner) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Admin Actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Edit Group Name'),
                      onTap: () => _showEditGroupDialog(context),
                    ),
                  ],

                  // Members Section with better loading states
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Members',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLoading ? '(loading...)' : '(${widget.group.members.length})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Show members or loading state
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (members.isEmpty)
                    _buildNoMembersView(context, widget.group.members.length)
                  else
                    ...members.map((member) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: member['isOwner'] == true
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: Text(
                          (member['displayName'] ?? 'User').toString().isNotEmpty 
                              ? (member['displayName'] ?? 'U').toString()[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: member['isOwner'] == true
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      title: Text(member['displayName']?.toString() ?? 'Unknown User'),
                      subtitle: member['isOwner'] == true
                          ? Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Group Owner',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : member['email'] != null && member['email'].toString().isNotEmpty
                              ? Text(
                                  member['email'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                    )).toList(),

                  const SizedBox(height: 24),
                  
                  // Leave Group action (without the "Danger Zone" text)
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Leave Group'),
                    textColor: Theme.of(context).colorScheme.error,
                    onTap: () => _showLeaveGroupDialog(context),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatistic(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditGroupDialog(BuildContext context) async {
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
          autofocus: true,
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
                if (context.mounted) {
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

  Future<void> _showLeaveGroupDialog(BuildContext context) async {
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
                  Navigator.pop(context); // Close settings screen
                  Navigator.pop(context); // Close group details screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully left the group')),
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
            child: Text(
              'Leave',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to show when there are no members to display
  Widget _buildNoMembersView(BuildContext context, int actualMemberCount) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to display member details',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              'Group has $actualMemberCount ${actualMemberCount == 1 ? 'member' : 'members'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Force refresh
                setState(() {});
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
