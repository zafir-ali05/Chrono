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

class _CalendarScreenState extends State<CalendarScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  
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

        if (isToday) {
          // Show categories for today's view
          // Get assignments for selected day
          final selectedDayAssignments = snapshot.data!.where((assignment) {
            final assignmentDate = DateTime(
              assignment.dueDate.year,
              assignment.dueDate.month,
              assignment.dueDate.day,
            );
            return assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
          }).toList();

          // Get upcoming assignments within a week
          final weekFromNow = now.add(const Duration(days: 7));
          final upcomingAssignments = snapshot.data!.where((assignment) {
            if (assignment.dueDate.isBefore(now)) return false;
            
            final assignmentDate = DateTime(
              assignment.dueDate.year,
              assignment.dueDate.month,
              assignment.dueDate.day,
            );
            
            return assignment.dueDate.isBefore(weekFromNow) && 
                   !assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
          }).toList();

          // Categorize assignments
          final overdue = <Assignment>[];
          final dueToday = <Assignment>[];
          final dueSoon = <Assignment>[];
          final dueThisWeek = <Assignment>[];

          // Sort selected day assignments
          for (final assignment in selectedDayAssignments) {
            if (assignment.dueDate.isBefore(now)) {
              overdue.add(assignment);
            } else {
              dueToday.add(assignment);
            }
          }

          // Sort upcoming assignments
          for (final assignment in upcomingAssignments) {
            final daysUntilDue = assignment.dueDate.difference(now).inDays;
            if (daysUntilDue <= 3) {
              dueSoon.add(assignment);
            } else {
              dueThisWeek.add(assignment);
            }
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
                ...overdue.map((a) => _buildEnhancedAssignmentTile(a)),
              ],
              if (dueToday.isNotEmpty) ...[
                _buildEnhancedSectionHeader('Due Today', Icons.event_rounded, Theme.of(context).colorScheme.primary, dueToday.length),
                ...dueToday.map((a) => _buildEnhancedAssignmentTile(a)),
              ],
              if (dueSoon.isNotEmpty) ...[
                _buildEnhancedSectionHeader('Due Soon', Icons.upcoming_rounded, Colors.orange, dueSoon.length),
                ...dueSoon.map((a) => _buildEnhancedAssignmentTile(a)),
              ],
              if (dueThisWeek.isNotEmpty) ...[
                _buildEnhancedSectionHeader('Later This Week', Icons.date_range_rounded, Colors.teal, dueThisWeek.length),
                ...dueThisWeek.map((a) => _buildEnhancedAssignmentTile(a)),
              ],
            ],
          );
        } else {
          // Show only assignments for the selected day
          final selectedDayAssignments = snapshot.data!.where((assignment) {
            final assignmentDate = DateTime(
              assignment.dueDate.year,
              assignment.dueDate.month,
              assignment.dueDate.day,
            );
            return assignmentDate.isAtSameMomentAs(normalizedSelectedDay);
          }).toList();

          if (selectedDayAssignments.isEmpty) {
            return _buildEmptyAssignmentsState(
              'No assignments due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}',
              Icons.event_available_rounded
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 100), // Extra padding for bottom nav
            children: [
              _buildEnhancedSectionHeader(
                'Due on ${_getMonthName(_selectedDay.month)} ${_selectedDay.day}', 
                Icons.event_rounded, 
                Theme.of(context).colorScheme.primary, 
                selectedDayAssignments.length
              ),
              ...selectedDayAssignments.map((a) => _buildEnhancedAssignmentTile(a)),
            ],
          );
        }
      },
    );
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

  // Enhanced section header with gradient and rounded corners
  Widget _buildEnhancedSectionHeader(String title, IconData icon, Color color, int count) {
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

  // Enhanced assignment tile with gradient and shadows
  Widget _buildEnhancedAssignmentTile(Assignment assignment) {
    final now = DateTime.now();
    final bool isOverdue = assignment.dueDate.isBefore(now);
    final int daysUntilDue = assignment.dueDate.difference(now).inDays;
    
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
                      fontSize: 16,
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
            // Add embedded tasks list with styling consistent with new design
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
    
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ListTile(
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
        EmbeddedTasksList(
          assignmentId: assignment.id,
          userId: _authService.currentUser?.uid ?? '',
          taskService: _taskService,
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month];
  }

  // Add this method inside _CalendarScreenState class
  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedNow = DateTime(now.year, now.month, now.day);
    return normalizedDate.isBefore(normalizedNow);
  }
}
