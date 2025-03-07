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
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _groupNameCache = {};
  String _searchTerm = '';
  bool _isSearching = false;
    
  // Store section expansion state
  final Map<String, bool> _expandedSections = {
    'Overdue': true,
    'Due Soon': true,
    'This Week': true,
    'Later': true,
  };
  
  // Store controllers for animations
  final Map<String, AnimationController> _animationControllers = {};

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
    
    // Initialize controllers with optimized settings
    for (final section in ['Overdue', 'Due Soon', 'This Week', 'Later']) {
      final isExpanded = _expandedSections[section] ?? true;
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
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
            // Custom app bar row with profile FAB
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 16, 8),
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
                          'Stay on track 🚀',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile FAB
                  GestureDetector(
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
                      child: Center(
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
                                // Clear the search term and dismiss keyboard
                                setState(() => _searchTerm = '');
                                // Dismiss the keyboard
                                FocusScope.of(context).unfocus();
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

  // New method to build animated assignments list with pre-built content
  Widget _buildAnimatedAssignmentsList(String sectionTitle, List<Assignment> assignments) {
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
      // Use consistent orange color for all "Due Soon" assignments
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_bottom_rounded; // Using rounded version
      statusGradient = LinearGradient(
        colors: [Colors.orange.shade300, Colors.orange.shade500], // Consistent orange gradient
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
    
    // Create title and className widgets here
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
            app_date_utils.getDueInDays(assignment.dueDate),
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
    
    // Now build and return the widget tree
    return RepaintBoundary(
      key: ValueKey(assignment.id), // Add key for better reuse
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
                padding: const EdgeInsets.only(top: 0, bottom: 12), // Increased bottom padding from 8 to 12
                child: EmbeddedTasksList(
                  assignmentId: assignment.id,
                  userId: _authService.currentUser?.uid ?? '',
                  taskService: _taskService,
                ),
              ),
            ],
          ),
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
        // Content - use AnimatedBuilder with ClipRect like in calendar_screen
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: widget.controller,
            child: Column(
              children: widget.assignments.map((assignment) => 
                _buildAssignmentTile(context, assignment)
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

// Helper class for text highlighting
class Match {
  final int start;
  final int end;
  
  Match(this.start, this.end);
}
