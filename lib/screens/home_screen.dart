import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../services/group_service.dart'; 
import 'assignment_details_screen.dart';
import '../widgets/embedded_tasks_list.dart';
import '../services/task_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService(); // Add this line at the top with other services
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _groupNameCache = {}; // Add cache to store group names
  String _searchTerm = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Assignment> _filterAssignments(List<Assignment> assignments, String query) {
    if (query.isEmpty) return assignments;
    
    final lowercaseQuery = query.toLowerCase();
    return assignments.where((assignment) {
      return assignment.name.toLowerCase().contains(lowercaseQuery) ||
             assignment.className.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your assignments'),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(28),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchTerm = value),
              decoration: InputDecoration(
                hintText: 'Search assignments or classes',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        
        // Stream of assignments - Updated to use getAllUserAssignments
        Expanded(
          child: StreamBuilder<List<Assignment>>(
            // Change this line to use getAllUserAssignments instead of getUserAssignments
            stream: _assignmentService.getAllUserAssignments(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error);
              }

              final assignments = snapshot.data ?? [];
              final filteredAssignments = _filterAssignments(assignments, _searchTerm);
              
              if (assignments.isEmpty) {
                return _buildEmptyState(context);
              }
              
              if (filteredAssignments.isEmpty) {
                return _buildNoSearchResultsState(context);
              }

              // Group assignments by timeframe
              final overdue = <Assignment>[];
              final dueSoon = <Assignment>[];
              final upcoming = <Assignment>[];
              final later = <Assignment>[];

              final now = DateTime.now();
              for (final assignment in filteredAssignments) {
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

              return _buildAssignmentsListView(
                context,
                overdue: overdue,
                dueSoon: dueSoon,
                upcoming: upcoming,
                later: later,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchTerm = '');
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear Search'),
          ),
        ],
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

  // ...existing error and empty state widgets...

  Widget _buildAssignmentsListView(
    BuildContext context, {
    required List<Assignment> overdue,
    required List<Assignment> dueSoon,
    required List<Assignment> upcoming,
    required List<Assignment> later,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Add a light section header for all assignments
        if (overdue.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Overdue',
            count: overdue.length,
            icon: Icons.warning_rounded,
            color: Colors.red,
          ),
          ...overdue.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (dueSoon.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Due Soon',
            count: dueSoon.length,
            icon: Icons.hourglass_top,
            color: Colors.orange,
          ),
          ...dueSoon.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'This Week',
            count: upcoming.length,
            icon: Icons.event,
            color: Theme.of(context).colorScheme.primary,
          ),
          ...upcoming.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (later.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Later',
            count: later.length,
            icon: Icons.calendar_month,
            color: Colors.grey,
          ),
          ...later.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        
        // Add information about search results if searching
        if (_searchTerm.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Showing ${overdue.length + dueSoon.length + upcoming.length + later.length} results for "$_searchTerm"',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  // ...existing _buildSectionHeader widget...

  Widget _buildAssignmentTile(BuildContext context, Assignment assignment) {
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    
    // More urgent color scheme
    final Color statusColor;
    final IconData statusIcon;
    
    if (isOverdue) {
      // Overdue assignments - red warning icon
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (daysUntilDue <= 3) {
      // Due within 3 days - red hourglass
      statusColor = Colors.red;
      statusIcon = Icons.hourglass_bottom;
    } else if (daysUntilDue <= 7) {
      // Due within a week - orange hourglass
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
    } else {
      // Due later - grey hourglass
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty;
    }
    
    // Highlight search term if present
    Widget titleWidget;
    Widget classNameWidget;
    
    if (_searchTerm.isNotEmpty) {
      titleWidget = _highlightSearchText(assignment.name, _searchTerm);
      classNameWidget = _highlightSearchText(assignment.className, _searchTerm);
    } else {
      titleWidget = Text(
        assignment.name,
        style: TextStyle(
          fontWeight: isOverdue ? FontWeight.w500 : FontWeight.normal,
          fontSize: 15,
        ),
      );
      classNameWidget = Text(
        assignment.className,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          title: titleWidget,
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: classNameWidget),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Classroom: ${_getGroupNameFromId(assignment.groupId)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      app_date_utils.getDueInDays(assignment.dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Icon(
              statusIcon,
              size: 18,
              color: statusColor,
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignmentDetailsScreen(assignment: assignment),
              ),
            );
          },
        ),
        // Add embedded tasks list after the ListTile
        EmbeddedTasksList(
          assignmentId: assignment.id,
          userId: _authService.currentUser?.uid ?? '',
          taskService: _taskService,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72, right: 16),
          child: Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  // Helper widget to highlight search text
  Widget _highlightSearchText(String text, String query) {
    if (query.isEmpty) {
      return Text(text);
    }
    
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    
    if (!lowercaseText.contains(lowercaseQuery)) {
      return Text(text);
    }
    
    final matches = <Match>[];
    int start = 0;
    while (true) {
      final matchIndex = lowercaseText.indexOf(lowercaseQuery, start);
      if (matchIndex == -1) break;
      matches.add(Match(matchIndex, matchIndex + query.length));
      start = matchIndex + query.length;
    }
    
    if (matches.isEmpty) {
      return Text(text);
    }
    
    final spans = <TextSpan>[];
    int currentIndex = 0;
    
    for (final match in matches) {
      if (currentIndex < match.start) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0x33FFEB3B),
        ),
      ));
      
      currentIndex = match.end;
    }
    
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }
    
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: currentIndex == 0 ? 15 : 13,
          color: currentIndex == 0 
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: spans,
      ),
    );
  }

  // ...existing helper methods...

  // Add this method to get group name
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

  @override
  void initState() {
    super.initState();
    // Fetch group names when assignments are loaded
    if (_authService.currentUser != null) {
      _assignmentService.getUserAssignments(_authService.currentUser!.uid)
        .listen((assignments) {
          for (var assignment in assignments) {
            _fetchGroupName(assignment.groupId);
          }
        });
    }
  }
}

// Helper class for text highlighting
class Match {
  final int start;
  final int end;
  
  Match(this.start, this.end);
}

// Add this method to your _HomeScreenState class
Widget _buildSectionHeader(
  BuildContext context, {
  required String title,
  required int count,
  required IconData icon,
  required Color color,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 0.25,
          ),
        ),
        const Spacer(),
        Text(
          '$count ${count == 1 ? 'item' : 'items'}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
