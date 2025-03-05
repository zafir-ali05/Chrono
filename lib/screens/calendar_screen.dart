import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Assignment>> _assignments = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
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

    return Column(
      children: [
        // Minimalist header
        _buildMinimalistHeader(),
        
        // Stream assignments and build calendar
        StreamBuilder<List<Assignment>>(
          stream: _assignmentService.getAllUserAssignments(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
              return const Expanded(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorWidget(snapshot.error);
            }

            // Process assignments
            final assignments = snapshot.data ?? [];
            
            if (_isLoading) {
              Future.microtask(() {
                if (mounted) setState(() => _isLoading = false);
              });
            }
          
            _processAssignments(assignments);

            return Expanded(
              child: Column(
                children: [
                  // Clean, minimalist calendar
                  Card(
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
                  
                  // Assignment list with a clean design
                  Expanded(
                    child: _buildAssignmentsList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Clean, minimalist header
  Widget _buildMinimalistHeader() {
    String monthName = _getMonthName(_focusedDay.month);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month and year with clean typography
          Text(
            '$monthName ${_focusedDay.year}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          // Simple navigation row
          Row(
            children: [
              // Today button with minimalist style
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
              
              // Navigation arrows with clean styling
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
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Expanded(
      child: Center(
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
      ),
    );
  }

  void _processAssignments(List<Assignment> assignments) {
    // Same implementation as before
    _assignments.clear();
    for (final assignment in assignments) {
      if (assignment.dueDate != null) {
        try {
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
  }
  
  // Clean, minimalist calendar with simplified styling
  Widget _buildMinimalistCalendar() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return TableCalendar(
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
        // Today styling - subtle highlight
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryColor, width: 1),
          color: Colors.transparent,
        ),
        todayTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        
        // Selected day - stronger highlight
        selectedDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        
        // Clean marker style - small dot
        markerDecoration: BoxDecoration(
          color: primaryColor.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
        markerSize: 6,
        markerMargin: const EdgeInsets.only(top: 6),
        
        // Weekend styling - subtle difference
        weekendTextStyle: TextStyle(color: Colors.red[300]),
        defaultTextStyle: TextStyle(color: textColor),
        
        // Outside days visibility
        outsideDaysVisible: false,
        
        // Cell margins for cleaner look
        cellMargin: const EdgeInsets.all(4),
      ),
      
      // Days of week style - clean and subtle
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: textColor.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          color: Colors.red[300]!.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    // If today is selected, show upcoming assignments, otherwise show selected day assignments
    if (isSameDay(_selectedDay, DateTime.now())) {
      return _buildUpcomingAssignments();
    } else {
      return _buildSelectedDayAssignments(_selectedDay);
    }
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
    
    // Enhanced urgency indicators
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
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      title: Text(
        assignment.name,
        style: TextStyle(
          fontWeight: isOverdue || daysUntilDue <= 3 ? FontWeight.w500 : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
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
            const SizedBox(height: 2),
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
          statusIcon, // Use our new status-specific icon
          size: 18,
          color: statusColor,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month];
  }
}
