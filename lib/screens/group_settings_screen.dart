import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/assignment.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../services/assignment_service.dart';
import '../services/storage_service.dart'; // Add this import
import '../widgets/animated_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this import
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
  late final StorageService _storageService; // Add storage service
  final ImagePicker _picker = ImagePicker(); // Add this
  bool _isUploading = false; // Add this state variable

  @override
  void initState() {
    super.initState();
    _groupService = GroupService();
    _authService = AuthService();
    _assignmentService = AssignmentService();
    _storageService = StorageService(); // Initialize storage service
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final isOwner = currentUser?.uid == widget.group.creatorId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classroom Settings'),
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
                  // Group Info Card with updated statistics and profile image
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
                              // Replace this Container with a profile image widget
                              Stack(
                                children: [
                                  FutureBuilder<String?>(
                                    future: _storageService.getGroupImageUrl(widget.group.id),
                                    builder: (context, snapshot) {
                                      final imageUrl = snapshot.data ?? widget.group.imageUrl;
                                      
                                      return GestureDetector(
                                        onTap: () => _showImageSourceDialog(context),
                                        child: Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: _isUploading
                                            ? const Center(child: CircularProgressIndicator())
                                            : ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: imageUrl != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: imageUrl,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Center(
                                                        child: Text(
                                                          widget.group.name[0].toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 24,
                                                            fontWeight: FontWeight.w500,
                                                            color: Theme.of(context).colorScheme.primary,
                                                          ),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Center(
                                                        child: Text(
                                                          widget.group.name[0].toUpperCase(),
                                                          style: TextStyle(
                                                            fontSize: 24,
                                                            fontWeight: FontWeight.w500,
                                                            color: Theme.of(context).colorScheme.primary,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : Center(
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
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  // Small camera icon at the bottom right
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Rest of your existing code for group name and code
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
                                      'Classroom Code: ${widget.group.id}',
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
                      title: const Text('Edit Classroom Name'),
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
                    ...members.map((member) => _buildMemberTile(context, member)).toList(),

                  const SizedBox(height: 24),
                  
                  // Leave Group action (without the "Danger Zone" text)
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Leave Classroom'),
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
    
    return showGeneralDialog<void>(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
        );

        return AnimatedDialog(
          animation: curvedAnimation,
          child: AlertDialog(
            title: const Text('Edit Classroom'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Classroom Name',
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
                        const SnackBar(content: Text('Classroom updated')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
    );
  }

  Future<void> _showLeaveGroupDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Classroom'),
        content: const Text('Are you sure you want to leave this classroom?'),
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
                    const SnackBar(content: Text('Successfully left the classroom')),
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
              'Classroom has $actualMemberCount ${actualMemberCount == 1 ? 'member' : 'members'}',
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

  // New method to build member tile with profile image
  Widget _buildMemberTile(BuildContext context, Map<String, dynamic> member) {
    final userId = member['uid'] as String?;
    final displayName = member['displayName'] as String? ?? 'Unknown User';
    final email = member['email'] as String? ?? '';
    final photoURL = member['photoURL'] as String?; // Get photoURL directly from member data
    final isOwner = member['isOwner'] as bool? ?? false;
    
    return ListTile(
      leading: CircleAvatar(
        radius: 20, // Set explicit radius for consistent size
        backgroundColor: isOwner
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).colorScheme.secondaryContainer,
        child: photoURL != null && photoURL.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoURL,
                  fit: BoxFit.cover,
                  width: 40, // Set explicit width
                  height: 40, // Set explicit height
                  placeholder: (context, url) => _buildInitial(context, displayName, isOwner),
                  errorWidget: (context, url, error) => _buildInitial(context, displayName, isOwner),
                ),
              )
            : _buildInitial(context, displayName, isOwner),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: isOwner ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: isOwner
          ? Row(
              children: [
                Icon(
                  Icons.star,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Classroom Owner',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : email.isNotEmpty
              ? Text(
                  email,
                  style: const TextStyle(fontSize: 12),
                )
              : null,
    );
  }

  // Helper method to build the initial avatar
  Widget _buildInitial(BuildContext context, String displayName, bool isOwner) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: TextStyle(
          color: isOwner
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Add this method to show the image source dialog
  Future<void> _showImageSourceDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Classroom Photo'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  child: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add this method to handle image picking and uploading
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      setState(() {
        _isUploading = true;
      });
      
      // Upload image to Firebase Storage
      final imageFile = File(pickedFile.path);
      final downloadUrl = await _storageService.uploadGroupImage(widget.group.id, imageFile);
      
      if (downloadUrl != null) {
        // Update group with new image URL
        await _groupService.updateGroupImage(widget.group.id, downloadUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Classroom picture updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating classroom picture: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}
