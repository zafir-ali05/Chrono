import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../models/group.dart'; // Add this line to import the Group class
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Assignment>> getGroupAssignments(String groupId) {
    print("Fetching assignments for group: $groupId"); // Debug print
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          print("Number of assignments found: ${snapshot.docs.length}"); // Debug print
          return snapshot.docs.map((doc) {
            print("Assignment data: ${doc.data()}"); // Debug print
            return Assignment.fromMap(
              doc.data(),
              id: doc.id,
              groupId: groupId,
            );
          }).toList();
        });
  }

  Stream<List<Assignment>> getUserAssignments(String userId) {
    print("Fetching assignments for user: $userId");
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .asyncMap((groupSnapshot) async {
          List<Assignment> allAssignments = [];
          
          for (var groupDoc in groupSnapshot.docs) {
            final groupId = groupDoc.id;
            print("Checking group: $groupId");
            
            final assignmentsSnapshot = await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assignments')
                .get();
                
            print("Found ${assignmentsSnapshot.docs.length} assignments in group $groupId");
            
            final groupAssignments = assignmentsSnapshot.docs.map((doc) {
              try {
                return Assignment.fromMap(
                  doc.data(),
                  id: doc.id,
                  groupId: groupId,
                );
              } catch (e) {
                print("Error parsing assignment in group $groupId: $e");
                return null;
              }
            }).whereType<Assignment>().toList();
            
            allAssignments.addAll(groupAssignments);
          }
          
          allAssignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          print("Total assignments after processing: ${allAssignments.length}");
          
          return allAssignments;
        });
  }

  Future<DocumentReference> createAssignment({
    required String groupId,
    required String className,
    required String name,
    required DateTime dueDate,
    required String creatorId,
  }) async {
    print("Creating assignment: $name for group: $groupId");
    
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('assignments')
          .add({
        'className': className,
        'name': name,
        'dueDate': Timestamp.fromDate(dueDate),
        'creatorId': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
        'notifiedOverdue': false,
      });

      print("Assignment created with ID: ${doc.id}");

      // Get group name for notification
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupName = groupDoc.data()?['name'];

      // Send notification for new assignment
      final notificationService = NotificationService();
      await notificationService.sendAssignmentNotification(
        groupId: groupId,
        groupName: groupName ?? 'Unknown Group',
        assignmentName: name,
        type: 'new',
      );

      return doc;
    } catch (e) {
      print("Error creating assignment: $e");
      rethrow; // Rethrow the error instead of creating a new Exception
    }
  }

  Future<void> updateAssignment({
    required String groupId,
    required String assignmentId,
    String? className,
    String? name,
    DateTime? dueDate,
  }) async {
    final Map<String, dynamic> updates = {};
    if (className != null) updates['className'] = className;
    if (name != null) updates['name'] = name;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .doc(assignmentId)
        .update(updates);
  }

  Future<void> deleteAssignment({
    required String groupId,
    required String assignmentId,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .doc(assignmentId)
        .delete();
  }

  /// Get all assignments for a user across all groups
  Stream<List<Assignment>> getAllUserAssignments(String userId) {
    return _firestore
        .collectionGroup('assignments')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Assignment> assignments = [];
      
      for (final doc in snapshot.docs) {
        try {
          // Safely get the group ID
          final groupPath = doc.reference.parent.parent?.path;
          if (groupPath == null) continue;
          
          final groupId = doc.reference.parent.parent!.id;
          
          // Check if user is a member of this group
          final groupDoc = await _firestore.collection('groups').doc(groupId).get();
          if (!groupDoc.exists) continue;
          
          final groupData = groupDoc.data();
          if (groupData == null) continue;
          
          // Check if the members field exists and contains the user
          final members = groupData['members'];
          if (members == null || !(members is List) || !members.contains(userId)) {
            continue;
          }
          
          // Safely create and add the assignment
          try {
            final assignmentData = doc.data();
            
            // Skip if required fields are missing
            if (!_validateAssignmentData(assignmentData)) {
              print('Skipping invalid assignment data: $assignmentData');
              continue;
            }
            
            final assignment = Assignment.fromMap(
              assignmentData,
              id: doc.id,
              groupId: groupId,
            );
            
            assignments.add(assignment);
          } catch (e) {
            print('Error creating assignment from doc ${doc.id}: $e');
            // Skip this assignment if there's an error
            continue;
          }
        } catch (e) {
          print('Error processing assignment doc: $e');
          // Skip this document if there's an error
          continue;
        }
      }
      
      return assignments;
    });
  }
  
  // Helper method to validate assignment data
  bool _validateAssignmentData(Map<String, dynamic> data) {
    // Check for required fields
    return data.containsKey('name') && 
           data.containsKey('className') && 
           data.containsKey('dueDate');
  }
  
  /// Get upcoming assignments for a user (due in the next week)
  Stream<List<Assignment>> getUpcomingAssignments(String userId) {
    final oneWeekFromNow = DateTime.now().add(const Duration(days: 7));
    
    return getAllUserAssignments(userId).map((assignments) {
      try {
        return assignments
            .where((assignment) => 
                assignment.dueDate.isAfter(DateTime.now()) && 
                assignment.dueDate.isBefore(oneWeekFromNow))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      } catch (e) {
        print('Error filtering upcoming assignments: $e');
        return [];
      }
    });
  }

  Stream<int> getGroupAssignmentCount(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
