import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:animations/animations.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../models/group.dart';
import 'group_details_screen.dart';
import '../services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';


class ClassroomsScreen extends StatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  State<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends State<ClassroomsScreen> {
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService(); // Move this to class level
  
  // Add a cache for group image URLs
  final Map<String, String?> _groupImageCache = {};
  
  @override
  void initState() {
    super.initState();
    // Preload group images when screen initializes
    _preloadGroupImages();
  }
  
  // Preload group images to reduce visible loading time
  Future<void> _preloadGroupImages() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      // Get groups first
      final groups = await _groupService.getUserGroupsOnce(user.uid);
      
      // Start loading all images in parallel
      final futures = groups.map((group) async {
        try {
          final imageUrl = await _storageService.getGroupImageUrl(group.id);
          // Store in cache
          _groupImageCache[group.id] = imageUrl;
        } catch (e) {
          // Ignore errors, just cache as null
          _groupImageCache[group.id] = null;
        }
      }).toList();
      
      // Wait for all to complete
      await Future.wait(futures);
      
      // Trigger rebuild if widget is still mounted
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error preloading group images: $e');
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Classroom'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Classroom Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                    content: Text('Please enter a classroom name'),
                  ),
                );
                return;
              }
              
              try {
                Navigator.of(dialogContext).pop();
                
                final group = await _groupService.createGroup(
                  nameController.text.trim(),
                  _authService.currentUser?.uid ?? '',
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      content: Text('Classroom created! Code: ${group.id}'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      content: Text('Error: ${e.toString()}'),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinGroupDialog() async {
    final codeController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Classroom'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Classroom Code',
            hintText: 'Enter the 6-character code',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                    content: Text('Please enter a classroom code'),
                  ),
                );
                return;
              }
              
              try {
                Navigator.of(dialogContext).pop();
                
                await _groupService.joinGroup(
                  codeController.text.trim().toUpperCase(),
                  _authService.currentUser?.uid ?? '',
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.all(16),
                      content: Text('Successfully joined classroom!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      content: Text(e.toString()),
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your classrooms'),
      );
    }

    // Apply gradient background like other screens
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: StreamBuilder<List<Group>>(
          stream: _groupService.getUserGroups(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorWidget(context, snapshot.error);
            }

            final groups = snapshot.data ?? [];
            
            return CustomScrollView(
              slivers: [
                // Header section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Classrooms',
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Join. Learn. Collaborate! 🏫',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Group list or empty state
                groups.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildEnhancedGroupTile(groups[index]),
                          childCount: groups.length,
                        ),
                      ),
                    ),
                
                // Add padding at the bottom for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            overlayColor: Colors.black,
            overlayOpacity: 0.4,
            spacing: 12,
            spaceBetweenChildren: 12,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            children: [
              SpeedDialChild(
                child: const Icon(Icons.group_add),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                labelBackgroundColor: Theme.of(context).colorScheme.surface,
                label: 'Create Classroom',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                onTap: _showCreateGroupDialog,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              SpeedDialChild(
                child: const Icon(Icons.login),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                labelBackgroundColor: Theme.of(context).colorScheme.surface,
                label: 'Join Classroom',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                onTap: _showJoinGroupDialog,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            'Could not load classrooms',
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
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {}),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Enhanced empty state with container and gradient
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
              Icons.group_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'No classrooms yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create a new classroom or join an existing one',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Enhanced buttons with gradients
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGradientButton(
                label: 'Create',
                icon: Icons.add_rounded,
                onTap: _showCreateGroupDialog,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              _buildGradientButton(
                label: 'Join',
                icon: Icons.group_add_rounded,
                onTap: _showJoinGroupDialog,
                primaryColor: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for gradient buttons
  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedGroupTile(Group group) {
    final membersCount = group.members.length;
    final userIsOwner = group.creatorId == _authService.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Generate a gradient color based on the group name (for visual variety)
    final int hashCode = group.name.hashCode;
    final Color baseColor = Color(0xFF000000 | (hashCode & 0xFFFFFF))
        .withOpacity(0.8)
        .withBlue(max(100, hashCode % 255))
        .withRed(max(100, (hashCode >> 8) % 255));
    
    final LinearGradient nameGradient = LinearGradient(
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Get cached URL or group's stored URL
    final imageUrl = _groupImageCache[group.id] ?? group.imageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          // Darker background gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDarkMode 
                  ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4) // Increased opacity
                  : Theme.of(context).colorScheme.surface.withOpacity(0.9), // Slightly darker
              isDarkMode
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
                  : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1), // More contrast
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          // Add subtle border for better definition
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.15) // Increased visibility
                : Theme.of(context).dividerColor.withOpacity(0.3), // More visible in light mode
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08), // Deeper shadow
              blurRadius: isDarkMode ? 14 : 12,
              offset: const Offset(0, 4),
              spreadRadius: isDarkMode ? 1 : 0,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: OpenContainer(
          transitionDuration: const Duration(milliseconds: 500),
          openBuilder: (context, _) => GroupDetailsScreen(group: group),
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          closedElevation: 0,
          closedColor: Colors.transparent,
          tappable: false,
          closedBuilder: (context, openContainer) => InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Enhanced group logo with better shadows
                  Hero(
                    tag: 'group-image-${group.id}',
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: imageUrl == null ? nameGradient : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: baseColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheHeight: 120,
                              memCacheWidth: 120,
                              placeholder: (context, url) => Center(
                                child: Text(
                                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '#',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '#',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                group.name.isNotEmpty ? group.name[0].toUpperCase() : '#',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Updated content layout with improved spacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Group info with improved visual styling
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start, // Align to left
                          children: [
                            // Members count pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$membersCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Code pill - now with intrinsic width instead of expanded
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min, // Keep pill to minimum width
                                children: [
                                  Icon(
                                    Icons.key_rounded,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    group.id,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (userIsOwner) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'Owner',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Removed the arrow icon here
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  
  // Helper function to prevent possible integer overflow
  int max(int a, int b) {
    return a > b ? a : b;
  }
}
