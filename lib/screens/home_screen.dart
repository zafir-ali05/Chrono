import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assignmentService = AssignmentService();
    final authService = AuthService();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text('Please sign in to view your assignments'),
      );
    }

    return StreamBuilder<List<Assignment>>(
      stream: assignmentService.getUserAssignments(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(context, snapshot.error);
        }

        final assignments = snapshot.data ?? [];
        if (assignments.isEmpty) {
          return _buildEmptyState(context);
        }

        // Group assignments by timeframe
        final overdue = <Assignment>[];
        final dueSoon = <Assignment>[];
        final upcoming = <Assignment>[];
        final later = <Assignment>[];

        final now = DateTime.now();
        for (final assignment in assignments) {
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
            Icons.check_circle_outline,
            size: 56,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No assignments due',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'When you create assignments, they will appear here',
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
          Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withOpacity(0.2)),
        ],
      ),
    );
  }

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
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          title: Text(
            assignment.name,
            style: TextStyle(
              fontWeight: isOverdue ? FontWeight.w500 : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      assignment.className,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                      'Group: ${_getGroupNameFromId(assignment.groupId)}',
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
                      statusIcon, // Use the status-specific icon
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
              statusIcon, // Use the status-specific icon
              size: 18,
              color: statusColor,
            ),
          ),
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

  // Helper to get group name - in real app, this would fetch from a cache or service
  String _getGroupNameFromId(String groupId) {
    // This would be replaced with actual group name lookup
    if (groupId.length > 5) {
      return groupId.substring(0, 5);
    }
    return groupId;
  }
}
