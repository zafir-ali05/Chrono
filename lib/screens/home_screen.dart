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
  final GroupService _groupService = GroupService();
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _groupNameCache = {};
  String _searchTerm = '';
  bool _isSearching = false;

  // Modified method to dismiss keyboard only when it's actually showing
  void _dismissKeyboard() {
    final FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

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
        child: Column(
          children: [
            // Simple Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 8), // Match search bar's left padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Add this
                children: [
                  Text(
                    'Upcoming Assignments',
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center, // Add this
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity, // Makes the container take full width
                    child: Text(
                      'Stay on track and ace your deadlines! 🚀',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center, // Centers the text
                    ),
                  ),
                ],
              ),
            ),

            // Enhanced search bar with more rounded corners and subtle shadow
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    // Only setState if the value actually changed to avoid unnecessary rebuilds
                    if (_searchTerm != value) {
                      setState(() => _searchTerm = value);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search assignments or classes',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      height: 1.0, // Adjust hint text alignment
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded, // Using rounded version
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    suffixIcon: _searchTerm.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16), // Using rounded version
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchTerm = '');
                              },
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    // Adjust padding to vertically center the text better
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.0, // Add this to ensure proper vertical alignment
                  ),
                  textAlignVertical: TextAlignVertical.center, // Add this to center text vertically
                  cursorColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            
            // Stream of assignments - wrap in RepaintBoundary to optimize rebuilds
            Expanded(
              child: RepaintBoundary(
                child: StreamBuilder<List<Assignment>>(
                  stream: _assignmentService.getAllUserAssignments(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          // Customized progress indicator
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
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
            ),
          ],
        ),
      ),
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

  Widget _buildAssignmentsListView(
    BuildContext context, {
    required List<Assignment> overdue,
    required List<Assignment> dueSoon,
    required List<Assignment> upcoming,
    required List<Assignment> later,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100), // Extra padding at bottom to account for nav bar
      children: [
        // Add redesigned section headers and assignment tiles
        if (overdue.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Overdue',
            count: overdue.length,
            icon: Icons.warning_rounded, // Using rounded icons
            color: Colors.red,
          ),
          ...overdue.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (dueSoon.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Due Soon',
            count: dueSoon.length,
            icon: Icons.hourglass_top_rounded, // Using rounded icons
            color: Colors.orange,
          ),
          ...dueSoon.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'This Week',
            count: upcoming.length,
            icon: Icons.event_rounded, // Using rounded icons
            color: Theme.of(context).colorScheme.primary,
          ),
          ...upcoming.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        if (later.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Later',
            count: later.length,
            icon: Icons.calendar_month_rounded, // Using rounded icons
            color: Colors.grey,
          ),
          ...later.map((assignment) => _buildAssignmentTile(context, assignment)),
        ],
        
        // Add information about search results if searching
        if (_searchTerm.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
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
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
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

  Widget _buildAssignmentTile(BuildContext context, Assignment assignment) {
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    
    // Status indicators with updated styling
    final Color statusColor;
    final IconData statusIcon;
    final LinearGradient statusGradient;
    
    if (isOverdue) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded; // Using rounded version
      statusGradient = LinearGradient(
        colors: [Colors.red.shade300, Colors.red.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (daysUntilDue <= 3) {
      statusColor = Colors.red;
      statusIcon = Icons.hourglass_bottom_rounded; // Using rounded version
      statusGradient = LinearGradient(
        colors: [Colors.red.shade200, Colors.red.shade400],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (daysUntilDue <= 7) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top_rounded; // Using rounded version
      statusGradient = LinearGradient(
        colors: [Colors.orange.shade300, Colors.orange.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty_rounded; // Using rounded version
      statusGradient = LinearGradient(
        colors: [Colors.grey.shade400, Colors.grey.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
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
                  title: titleWidget,
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: classNameWidget),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
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
                                app_date_utils.getDueInDays(assignment.dueDate),
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
                ),
              ),
            ),
            // Add embedded tasks list after the ListTile with updated styling
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
