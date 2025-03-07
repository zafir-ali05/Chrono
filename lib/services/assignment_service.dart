import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Add cache for assignments
  final Map<String, List<Assignment>> _assignmentsCache = {};

  Stream<List<Assignment>> getGroupAssignments(String groupId) {
    // First emit cached data if available
    List<Assignment>? cachedAssignments = _assignmentsCache[groupId];
    
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs.map((doc) {
            return Assignment.fromMap(
              doc.data(),
              id: doc.id,
              groupId: groupId,
            );
          }).toList();
          
          // Update cache
          _assignmentsCache[groupId] = assignments;
          
          return assignments;
        }).startWith(cachedAssignments ?? []);  // Emit cached data first
  }

  // Update the getUserAssignments method to use the same optimized approach
  Stream<List<Assignment>> getUserAssignments(String userId) {
    // Redirect to getAllUserAssignments for consistency
    return getAllUserAssignments(userId);
  }

  Stream<List<Assignment>> getUserAssignmentsOld(String userId) {
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

      // Update cache immediately
      final newAssignment = Assignment(
        id: doc.id,
        groupId: groupId,
        className: className,
        name: name,
        dueDate: dueDate,
        creatorId: creatorId,
        createdAt: DateTime.now(),
      );
      
      _assignmentsCache[groupId] = [
        ...(_assignmentsCache[groupId] ?? []),
        newAssignment,
      ];

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

  Stream<List<Assignment>> getAllUserAssignments(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .switchMap((groupSnapshot) {
          final streams = groupSnapshot.docs.map((groupDoc) {
            final groupId = groupDoc.id;
            return _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assignments')
                .snapshots()
                .map((assignmentSnapshot) {
                  final assignments = assignmentSnapshot.docs.map((doc) {
                    return Assignment.fromMap(
                      doc.data(),
                      id: doc.id,
                      groupId: groupId,
                    );
                  }).toList();
                  
                  // Update cache for this group
                  _assignmentsCache[groupId] = assignments;
                  
                  return assignments;
                });
          });
          
          // Combine all streams into one
          return streams.isEmpty 
              ? Stream.value(<Assignment>[]) 
              : Rx.combineLatestList(streams).map((lists) => 
                  lists.expand((list) => list).toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate))
                );
        });
  }

  // Add this method to get upcoming assignments
  Stream<List<Assignment>> getUpcomingAssignments(String userId) {
    final now = DateTime.now();
    
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .asyncMap((groupSnapshot) async {
          List<Assignment> upcomingAssignments = [];
          
          for (var groupDoc in groupSnapshot.docs) {
            final groupId = groupDoc.id;
            
            final assignmentsSnapshot = await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assignments')
                .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
                .orderBy('dueDate')
                .get();
            
            final groupAssignments = assignmentsSnapshot.docs.map((doc) {
              return Assignment.fromMap(
                doc.data(),
                id: doc.id,
                groupId: groupId,
              );
            }).toList();
            
            upcomingAssignments.addAll(groupAssignments);
          }
          
          // Sort assignments by due date
          upcomingAssignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return upcomingAssignments;
        });
  }

  Future<void> markAssignmentComplete({
    required String assignmentId,
    required String userId,
    bool complete = true,
  }) async {
    if (assignmentId.isEmpty || userId.isEmpty) {
      throw ArgumentError('Assignment ID and User ID cannot be empty');
    }
    
    try {
      final documentId = '${assignmentId}_$userId';
      final docRef = _firestore.collection('completedAssignments').doc(documentId);
      
      if (complete) {
        // Mark as complete
        await docRef.set({
          'assignmentId': assignmentId,
          'userId': userId,
          'completedAt': FieldValue.serverTimestamp(),
        });
        
        // Add debug print
        print('Assignment marked complete: $documentId');
      } else {
        // Mark as incomplete by deleting the document
        await docRef.delete();
        
        // Add debug print
        print('Assignment marked incomplete: $documentId');
      }
    } catch (e) {
      print('Error marking assignment ${complete ? "complete" : "incomplete"}: $e');
      throw e;
    }
  }

  Stream<bool> isAssignmentCompleted(String assignmentId, String userId) {
    if (assignmentId.isEmpty || userId.isEmpty) {
      // Return a stream of false if either ID is empty
      return Stream.value(false);
    }
    
    final documentId = '${assignmentId}_$userId';
    return _firestore
        .collection('completedAssignments')
        .doc(documentId)
        .snapshots()
        .map((doc) {
          final exists = doc.exists;
          // Add debug print
          print('Checking completion status for $documentId: $exists');
          return exists;
        });
  }
}
