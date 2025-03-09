import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart' as app_date_utils;
import 'package:animations/animations.dart';
import 'assignment_details_screen.dart';
import '../widgets/embedded_tasks_list.dart';
import '../services/task_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Assignment>> _assignments = {};
  bool _isLoading = true;
  
  // Add section expansion state map like in home_screen.dart
  final Map<String, bool> _expandedSections = {
    'Overdue': true,
    'Due Today': true,
    'Due Soon': true,
    'Later This Week': true, 
  };
  
  // Add animation controllers map
  final Map<String, AnimationController> _animationControllers = {};
  
  // Add this property to _CalendarScreenState to track when a refresh is needed
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    
    // Initialize animation controllers for each section
    _animationControllers['Overdue'] = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // Start expanded
    );
    
    _animationControllers['Due Today'] = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // Start expanded
    );
    
    _animationControllers['Due Soon'] = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // Start expanded
    );
    
    _animationControllers['Later This Week'] = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // Start expanded
    );
    
    // Initialize for the current selected day section
    _initSelectedDayController();
    
    // Add a listener for assignment completion status changes
    _assignmentService.onAssignmentStatusChanged.listen((_) {
      // Force refresh on next build
      if (mounted) {
        setState(() {
          _needsRefresh = true;
        });
      }
    });
  }
  
  // Create a separate method to initialize or update the selected day controller
  void _initSelectedDayController() {
    final String selectedDayTitle = 'Due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
    
    // Only create if doesn't exist
    if (!_animationControllers.containsKey(selectedDayTitle)) {
      _animationControllers[selectedDayTitle] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        value: 1.0, // Start expanded
      );
      
      // Also initialize its expanded state
      _expandedSections[selectedDayTitle] = true;
    }
  }
  
  // Clean up any old selected day controllers that are no longer needed
  void _cleanupOldControllers() {
    // Get current selected day title
    final String currentDayTitle = 'Due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
    
    // Find old selected day controllers
    final oldControllers = _animationControllers.keys
        .where((key) => key.startsWith('Due on ') && key != currentDayTitle)
        .toList();
    
    // Remove old controllers that aren't the current day
    for (final key in oldControllers) {
      final controller = _animationControllers[key];
      if (controller != null) {
        controller.dispose();
        _animationControllers.remove(key);
      }
      // Also remove from expanded sections map
      _expandedSections.remove(key);
    }
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    // Handle the case when user is not authenticated
    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your calendar'),
      );
    }

    return Container(
      // Add gradient background like home screen
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
          final isLoading = snapshot.connectionState == ConnectionState.waiting && _isLoading;
          final hasError = snapshot.hasError;
          
          // Process assignments in advance for the calendar
          if (!isLoading && !hasError && snapshot.hasData) {
            _processAssignments(snapshot.data ?? []);
            
            if (_isLoading) {
              Future.microtask(() {
                if (mounted) setState(() => _isLoading = false);
              });
            }
          }

          return CustomScrollView(
            slivers: [
              // App bar with header
              SliverToBoxAdapter(
                child: _buildMinimalistHeader(),
              ),
              
              // Calendar
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildMinimalistCalendar(),
                ),
              ),
              
              // Handle loading, error, or content
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasError)
                SliverFillRemaining(
                  child: _buildErrorWidget(snapshot.error),
                )
              else
                _buildAssignmentsListSlivers(user.uid),
                
              // Add padding at the bottom for navigation bar
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverToBoxAdapter(child: Container()),
              ),
            ],
          );
        },
      ),
    );
  }

  // New method to build assignment list slivers
  Widget _buildAssignmentsListSlivers(String userId) {
    final normalizedSelectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final isToday = normalizedSelectedDay.isAtSameMomentAs(normalizedToday);
    
    return StreamBuilder<List<Assignment>>(
      stream: _assignmentService.getAllUserAssignments(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Reset refresh flag whenever we build with fresh data
        if (_needsRefresh) {
          _needsRefresh = false;
        }

        // Get assignments for selected day
        final allAssignments = snapshot.data!;
        
        final selectedDayAssignments = allAssignments.where((assignment) {
          final assignmentDate = DateTime(
            assignment.dueDate.year,
            assignment.dueDate.month,
            assignment.dueDate.day,
          );
          return assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
        }).toList();
        
        if (isToday) {
          // Today view with categories
          final weekFromNow = now.add(const Duration(days: 7));
          final upcomingAssignments = allAssignments.where((assignment) {
            if (assignment.dueDate.isBefore(now)) return false;
            
            final assignmentDate = DateTime(
              assignment.dueDate.year,
              assignment.dueDate.month,
              assignment.dueDate.day,
            );
            
            return assignment.dueDate.isBefore(weekFromNow) && 
                  !assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
          }).toList();

          return FutureBuilder<List<List<Assignment>>>(
            future: _categorizeAssignments(
              [...selectedDayAssignments, ...upcomingAssignments], 
              userId
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final categories = snapshot.data!;
              final overdue = categories[0];
              final dueToday = categories[1];
              final dueSoon = categories[2];
              final dueThisWeek = categories[3];
              final completed = categories[4];
              
              // Initialize Completed section controller if needed
              if (!_animationControllers.containsKey('Completed') && completed.isNotEmpty) {
                _animationControllers['Completed'] = AnimationController(
                  vsync: this,
                  duration: const Duration(milliseconds: 250),
                  value: (_expandedSections['Completed'] ?? false) ? 1.0 : 0.0,
                );
                _expandedSections['Completed'] = _expandedSections['Completed'] ?? false;
              }

              if (selectedDayAssignments.isEmpty && upcomingAssignments.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyAssignmentsState(
                    'No assignments due today or in the upcoming week',
                    Icons.check_circle_outline_rounded
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (overdue.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Overdue', Icons.warning_rounded, Colors.red, overdue.length),
                    _buildAnimatedAssignmentsList('Overdue', overdue),
                  ],
                  if (dueToday.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Due Today', Icons.event_rounded, Theme.of(context).colorScheme.primary, dueToday.length),
                    _buildAnimatedAssignmentsList('Due Today', dueToday),
                  ],
                  if (dueSoon.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Due Soon', Icons.upcoming_rounded, Colors.orange, dueSoon.length),
                    _buildAnimatedAssignmentsList('Due Soon', dueSoon),
                  ],
                  if (dueThisWeek.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Later This Week', Icons.date_range_rounded, Colors.teal, dueThisWeek.length),
                    _buildAnimatedAssignmentsList('Later This Week', dueThisWeek),
                  ],
                  if (completed.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Completed', Icons.check_circle_rounded, Colors.green, completed.length),
                    _buildAnimatedAssignmentsList('Completed', completed),
                  ],
                ]),
              );
            }
          );
        } else {
          // Selected day view
          return FutureBuilder<List<Assignment>>(
            future: _checkCompletionForAssignments(selectedDayAssignments, userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final assignmentsWithStatus = snapshot.data!;
              final completedAssignments = assignmentsWithStatus.where((a) => a.isCompleted).toList();
              final pendingAssignments = assignmentsWithStatus.where((a) => !a.isCompleted).toList();

              final String completedTitle = 'Completed, was due ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
              if (!_animationControllers.containsKey(completedTitle) && completedAssignments.isNotEmpty) {
                _animationControllers[completedTitle] = AnimationController(
                  vsync: this,
                  duration: const Duration(milliseconds: 250),
                  value: (_expandedSections[completedTitle] ?? false) ? 1.0 : 0.0,
                );
                _expandedSections[completedTitle] = _expandedSections[completedTitle] ?? false;
              }

              if (assignmentsWithStatus.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyAssignmentsState(
                    'No assignments due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}',
                    Icons.event_available_rounded
                  ),
                );
              }

              final String sectionTitle = 'Due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
              _initSelectedDayController();

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (pendingAssignments.isNotEmpty) ...[
                    _buildEnhancedSectionHeader(
                      sectionTitle, 
                      Icons.event_rounded, 
                      Theme.of(context).colorScheme.primary, 
                      pendingAssignments.length
                    ),
                    _buildAnimatedAssignmentsList(
                      sectionTitle, 
                      pendingAssignments
                    ),
                  ],
                  if (completedAssignments.isNotEmpty) ...[
                    _buildEnhancedSectionHeader(
                      completedTitle,
                      Icons.check_circle_rounded,
                      Colors.green,
                      completedAssignments.length
                    ),
                    _buildAnimatedAssignmentsList(
                      completedTitle,
                      completedAssignments
                    ),
                  ],
                ]),
              );
            }
          );
        }
      },
    );
  }

  // Clean, minimalist header
  Widget _buildMinimalistHeader() {
    String monthName = _getMonthName(_focusedDay.month);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 8), // Changed padding to match home screen
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Main title with matching style
          Text(
            'Calendar',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Subtitle with matching style
          SizedBox(
            width: double.infinity,
            child: Text(
              'Stay Ahead of Your Schedule! 🗓️',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Month navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName ${_focusedDay.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      final now = DateTime.now();
                      _focusedDay = now;
                      _selectedDay = now;
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_before, size: 22),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (_focusedDay.month == 1) {
                        _focusedDay = DateTime(_focusedDay.year - 1, 12, 1);
                      } else {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                      }
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next, size: 22),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (_focusedDay.month == 12) {
                        _focusedDay = DateTime(_focusedDay.year + 1, 1, 1);
                      } else {
                        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                      }
                    }),
                  ),
                ],
              ),
            ],
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
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() => _isLoading = true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _processAssignments(List<Assignment> assignments) {
    _assignments.clear();
    for (final assignment in assignments) {
      try {
        // Normalize the date to remove time component
        final day = DateTime(
          assignment.dueDate.year,
          assignment.dueDate.month,
          assignment.dueDate.day,
        );
        
        if (_assignments.containsKey(day)) {
          _assignments[day]!.add(assignment);
        } else {
          _assignments[day] = [assignment];
        }
      } catch (e) {
        print('Error processing assignment date: $e');
        continue;
      }
    }
  }
  
  // Clean, minimalist calendar with simplified styling
  Widget _buildMinimalistCalendar() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime(2021, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        headerVisible: false, // Using custom header
        daysOfWeekHeight: 32,
        rowHeight: 42,
        
        // Clean selection style
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        
        // Simplified event loading
        eventLoader: (day) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          return _assignments[normalizedDay] ?? [];
        },
        
        // Standard callbacks
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            
            // Initialize controller for the newly selected day
            _initSelectedDayController();
            
            // Optionally clean up old controllers
            _cleanupOldControllers();
          });
        },
        
        // Calendar format cycling with minimalist UI
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
          CalendarFormat.week: 'Week',
        },
        onFormatChanged: (format) => setState(() => _calendarFormat = format),
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
        
        // Clean styling for calendar
        calendarStyle: CalendarStyle(
          // Today styling - subtle highlight with gradient
          todayDecoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.15),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
          
          // Selected day - stronger highlight with gradient
          selectedDecoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          
          // Marker style - clean and modern
          markerDecoration: BoxDecoration(
            color: primaryColor.withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          markersMaxCount: 1,
          markerSize: 6,
          markerMargin: const EdgeInsets.only(top: 7),
          
          // Cell styling
          cellMargin: const EdgeInsets.all(6),
          cellPadding: EdgeInsets.zero,
          
          // Text styling
          defaultTextStyle: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          weekendTextStyle: TextStyle(
            color: Colors.red.shade300,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          outsideTextStyle: TextStyle(
            color: textColor.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
        
        // Weekday header styling
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          weekendStyle: TextStyle(
            color: Colors.red.shade300.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
        ),
        
        // Calendar builders
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            
            final isSelected = isSameDay(date, _selectedDay);
            final isToday = isSameDay(date, DateTime.now());
            
            // Don't show marker if day is selected or today
            if (isSelected || isToday) return null;
            
            return Positioned(
              bottom: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isOverdue(date)
                        ? [Colors.red.shade300, Colors.red.shade400]
                        : [primaryColor.withOpacity(0.7), primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isOverdue(date)
                          ? Colors.red.withOpacity(0.3)
                          : primaryColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    final normalizedSelectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    final isToday = normalizedSelectedDay.isAtSameMomentAs(normalizedToday);
    
    final user = _authService.currentUser;
    if (user == null) {
      return const SizedBox();
    }

    return StreamBuilder<List<Assignment>>(
      stream: _assignmentService.getAllUserAssignments(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        
        // Reset refresh flag whenever we build with fresh data
        if (_needsRefresh) {
          _needsRefresh = false;
        }

        // Process assignments and manually check completion status
        final allAssignments = snapshot.data!;
        final userId = _authService.currentUser?.uid ?? '';
        
        // Get assignments for selected day
        final selectedDayAssignments = allAssignments.where((assignment) {
          final assignmentDate = DateTime(
            assignment.dueDate.year,
            assignment.dueDate.month,
            assignment.dueDate.day,
          );
          return assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
        }).toList();
        
        if (isToday) {
          // Show categories for today's view
          // Get upcoming assignments within a week
          final weekFromNow = now.add(const Duration(days: 7));
          final upcomingAssignments = allAssignments.where((assignment) {
            if (assignment.dueDate.isBefore(now)) return false;
            
            final assignmentDate = DateTime(
              assignment.dueDate.year,
              assignment.dueDate.month,
              assignment.dueDate.day,
            );
            
            return assignment.dueDate.isBefore(weekFromNow) && 
                  !assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
          }).toList();

          // Add loading feedback while checking completion status
          return FutureBuilder<List<List<Assignment>>>(
            future: _categorizeAssignments(
              [...selectedDayAssignments, ...upcomingAssignments], 
              userId
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final categories = snapshot.data!;
              final overdue = categories[0];
              final dueToday = categories[1];
              final dueSoon = categories[2];
              final dueThisWeek = categories[3];
              final completed = categories[4];
              
              // Initialize animation controller for Completed section if needed
              if (!_animationControllers.containsKey('Completed') && completed.isNotEmpty) {
                _animationControllers['Completed'] = AnimationController(
                  vsync: this,
                  duration: const Duration(milliseconds: 250),
                  value: (_expandedSections['Completed'] ?? false) ? 1.0 : 0.0,
                );
                _expandedSections['Completed'] = _expandedSections['Completed'] ?? false;
              }

              if (selectedDayAssignments.isEmpty && upcomingAssignments.isEmpty) {
                return _buildEmptyAssignmentsState(
                  'No assignments due today or in the upcoming week',
                  Icons.check_circle_outline_rounded
                );
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 100), // Extra padding for bottom nav
                children: [
                  if (overdue.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Overdue', Icons.warning_rounded, Colors.red, overdue.length),
                    _buildAnimatedAssignmentsList('Overdue', overdue),
                  ],
                  if (dueToday.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Due Today', Icons.event_rounded, Theme.of(context).colorScheme.primary, dueToday.length),
                    _buildAnimatedAssignmentsList('Due Today', dueToday),
                  ],
                  if (dueSoon.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Due Soon', Icons.upcoming_rounded, Colors.orange, dueSoon.length),
                    _buildAnimatedAssignmentsList('Due Soon', dueSoon),
                  ],
                  if (dueThisWeek.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Later This Week', Icons.date_range_rounded, Colors.teal, dueThisWeek.length),
                    _buildAnimatedAssignmentsList('Later This Week', dueThisWeek),
                  ],
                  if (completed.isNotEmpty) ...[
                    _buildEnhancedSectionHeader('Completed', Icons.check_circle_rounded, Colors.green, completed.length),
                    _buildAnimatedAssignmentsList('Completed', completed),
                  ],
                ],
              );
            }
          );
        } else {
          // Selected day is not today
          // Add loading feedback while checking completion status
          return FutureBuilder<List<Assignment>>(
            future: _checkCompletionForAssignments(selectedDayAssignments, userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              // Now all assignments have proper isCompleted flags set
              final assignmentsWithStatus = snapshot.data!;
              
              // Split assignments by completion status
              final completedAssignments = assignmentsWithStatus.where((a) => a.isCompleted).toList();
              final pendingAssignments = assignmentsWithStatus.where((a) => !a.isCompleted).toList();

              // Initialize animation controllers if needed
              final String completedTitle = 'Completed, was due ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
              if (!_animationControllers.containsKey(completedTitle) && completedAssignments.isNotEmpty) {
                _animationControllers[completedTitle] = AnimationController(
                  vsync: this,
                  duration: const Duration(milliseconds: 250),
                  value: (_expandedSections[completedTitle] ?? false) ? 1.0 : 0.0,
                );
                _expandedSections[completedTitle] = _expandedSections[completedTitle] ?? false;
              }

              if (assignmentsWithStatus.isEmpty) {
                return _buildEmptyAssignmentsState(
                  'No assignments due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}',
                  Icons.event_available_rounded
                );
              }

              final String sectionTitle = 'Due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}';
              _initSelectedDayController();

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  if (pendingAssignments.isNotEmpty) ...[
                    _buildEnhancedSectionHeader(
                      sectionTitle, 
                      Icons.event_rounded, 
                      Theme.of(context).colorScheme.primary, 
                      pendingAssignments.length
                    ),
                    _buildAnimatedAssignmentsList(
                      sectionTitle, 
                      pendingAssignments
                    ),
                  ],
                  if (completedAssignments.isNotEmpty) ...[
                    _buildEnhancedSectionHeader(
                      completedTitle,
                      Icons.check_circle_rounded,
                      Colors.green,
                      completedAssignments.length
                    ),
                    _buildAnimatedAssignmentsList(
                      completedTitle,
                      completedAssignments
                    ),
                  ],
                ],
              );
            }
          );
        }
      },
    );
  }

  // Add these helper methods to check completion status

  // Efficiently check completion status for a list of assignments
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

  // Categorize assignments by due date and completion status
  Future<List<List<Assignment>>> _categorizeAssignments(List<Assignment> assignments, String userId) async {
    // Check completion status for all assignments first
    final assignmentsWithStatus = await _checkCompletionForAssignments(assignments, userId);
    
    final now = DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);
    
    // Initialize categories
    final overdue = <Assignment>[];
    final dueToday = <Assignment>[];
    final dueSoon = <Assignment>[];
    final dueThisWeek = <Assignment>[];
    final completed = <Assignment>[];
    
    // Categorize assignments
    for (final assignment in assignmentsWithStatus) {
      if (assignment.isCompleted) {
        completed.add(assignment);
      } else {
        final assignmentDate = DateTime(
          assignment.dueDate.year, 
          assignment.dueDate.month, 
          assignment.dueDate.day
        );
        
        if (assignment.dueDate.isBefore(now)) {
          overdue.add(assignment);
        } else if (assignmentDate.isAtSameMomentAs(normalizedToday)) {
          dueToday.add(assignment);
        } else if (assignment.dueDate.difference(now).inDays <= 3) {
          dueSoon.add(assignment);
        } else {
          dueThisWeek.add(assignment);
        }
      }
    }
    
    return [overdue, dueToday, dueSoon, dueThisWeek, completed];
  }

  // Enhanced empty state with bubbly styling
  Widget _buildEmptyAssignmentsState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              icon,
              size: 40,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
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
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced section header with collapsible functionality
  Widget _buildEnhancedSectionHeader(String title, IconData icon, Color color, int count) {
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
              // Use a callback to avoid immediate setState impact
              Future.microtask(() {
                setState(() {
                  _expandedSections[title] = !isExpanded;
                });
              });
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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

  // Add method to build animated assignments list with pre-built content
  Widget _buildAnimatedAssignmentsList(String sectionTitle, List<Assignment> assignments) {
    final controller = _animationControllers[sectionTitle];
    if (controller == null) {
      // If controller doesn't exist (which shouldn't happen since we initialize all of them),
      // just return the assignments directly without animation
      return Column(
        children: assignments.map((a) => _buildEnhancedAssignmentTile(a)).toList(),
      );
    }
    
    final isExpanded = _expandedSections[sectionTitle] ?? true;
    
    // Move animation triggers outside the build cycle using post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isExpanded && controller.status != AnimationStatus.completed && 
          controller.status != AnimationStatus.forward) {
        controller.forward();
      } else if (!isExpanded && controller.status != AnimationStatus.dismissed && 
                controller.status != AnimationStatus.reverse) {
        controller.reverse();
      }
    });
    
    // Pre-build content to avoid rebuilding during animation
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        child: Column(
          children: assignments.map((a) => _buildEnhancedAssignmentTile(a)).toList(),
        ),
        builder: (context, child) {
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: controller.value,
              child: child,
            ),
          );
        },
      ),
    );
  }

  // Enhanced assignment tile with gradient and shadows
  Widget _buildEnhancedAssignmentTile(Assignment assignment) {
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    final userId = _authService.currentUser?.uid ?? '';
    
    // Add StreamBuilder to track completion status for this specific assignment
    return StreamBuilder<bool>(
      stream: _assignmentService.isAssignmentCompleted(assignment.id, userId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;
        
        // Set completion status in the Assignment object for consistency
        if (assignment.isCompleted != isCompleted) {
          // Status changed - ensure we get a rebuild with fresh categorization
          assignment.isCompleted = isCompleted;
          
          // Force a rebuild on the next frame
          if (!_needsRefresh) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {
                _needsRefresh = true;
              });
            });
          }
        }
        
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
        
        // Check if we're in dark mode
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Padding(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
          ),
        );
      },
    );
  }

  Widget _buildUpcomingAssignments() {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view assignments'));
    }

    return StreamBuilder<List<Assignment>>(
      stream: _assignmentService.getUpcomingAssignments(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final assignments = snapshot.data ?? [];
        if (assignments.isEmpty) {
          return _buildEmptyState('No upcoming assignments');
        }

        return _buildAssignmentsListView(
          'Upcoming Assignments',
          assignments,
          Icons.upcoming,
        );
      },
    );
  }

  Widget _buildSelectedDayAssignments(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final assignmentsForDay = _assignments[normalizedDay] ?? [];
    
    final String formattedDate = '${_getMonthName(day.month)} ${day.day}';

    if (assignmentsForDay.isEmpty) {
      return _buildEmptyState('No assignments due on $formattedDate');
    }

    return _buildAssignmentsListView(
      'Due on $formattedDate',
      assignmentsForDay,
      Icons.event,
    );
  }

  // Clean empty state widget
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Clean assignments list view
  Widget _buildAssignmentsListView(String title, List<Assignment> assignments, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                  letterSpacing: 0.25,
                ),
              ),
              const Spacer(),
              Text(
                '${assignments.length} ${assignments.length == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // Clean divider
        Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withOpacity(0.2)),
        
        // Clean list of assignments
        Expanded(
          child: ListView.separated(
            itemCount: assignments.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
            itemBuilder: (context, index) => _buildMinimalistAssignmentTile(assignments[index]),
          ),
        ),
      ],
    );
  }

  // Clean, minimalist assignment tile
  Widget _buildMinimalistAssignmentTile(Assignment assignment) {
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    final userId = _authService.currentUser?.uid ?? '';
    
    // Add StreamBuilder to track completion status for this specific assignment
    return StreamBuilder<bool>(
      stream: _assignmentService.isAssignmentCompleted(assignment.id, userId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? false;
        
        // Set completion status in the Assignment object for consistency
        assignment.isCompleted = isCompleted;
        
        // Enhanced urgency indicators
        final Color statusColor;
        final IconData statusIcon;
        
        if (isCompleted) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_rounded;
        } else if (isOverdue) {
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
        
        // Check for dark mode
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                // Add subtle highlighting in dark mode for better visibility
                color: isDarkMode && isOverdue 
                    ? Colors.red.withOpacity(0.05) 
                    : null,
                border: isDarkMode 
                    ? Border(
                        left: BorderSide(
                          color: statusColor.withOpacity(0.5),
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
                    // Status indicator on the right
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : app_date_utils.getDueInDays(assignment.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(isDarkMode ? 0.5 : 0.3),
                      width: isDarkMode ? 1.0 : 0.5,
                    ),
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
            ),
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 4), // Reduced top padding to 0
              child: EmbeddedTasksList(
                assignmentId: assignment.id,
                userId: _authService.currentUser?.uid ?? '',
                taskService: _taskService,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month];
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedNow = DateTime(now.year, now.month, now.day);
    return normalizedDate.isBefore(normalizedNow);
  }
}
