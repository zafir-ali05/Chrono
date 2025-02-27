import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(assignment.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${assignment.className}'),
            Text(
              getDueInDays(assignment.dueDate),
              style: TextStyle(
                color: assignment.dueDate.isBefore(DateTime.now())
                    ? Colors.red
                    : assignment.dueDate.difference(DateTime.now()).inDays <= 3
                        ? Colors.orange
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Assignment>>(
        stream: _assignmentService.getUserAssignments(_authService.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = snapshot.data!;
          if (assignments.isEmpty) {
            return const Center(
              child: Text('No assignments yet'),
            );
          }

          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) => 
                _buildAssignmentCard(assignments[index]),
          );
        },
      ),
    );
  }
}
