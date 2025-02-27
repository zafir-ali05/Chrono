import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  List<Assignment> _filterAssignments(List<Assignment> assignments, String query) {
    if (query.isEmpty) return assignments;
    
    query = query.toLowerCase();
    return assignments.where((assignment) {
      return assignment.name.toLowerCase().contains(query) ||
             assignment.className.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          assignment.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search assignments or classes...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchTerm.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchTerm = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _searchTerm = value),
              padding: const MaterialStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Assignment>>(
              stream: _assignmentService.getUserAssignments(_authService.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredAssignments = _filterAssignments(snapshot.data!, _searchTerm);

                if (filteredAssignments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchTerm.isEmpty 
                            ? 'No assignments yet'
                            : 'No assignments match your search',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredAssignments.length,
                  itemBuilder: (context, index) => 
                      _buildAssignmentCard(filteredAssignments[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
