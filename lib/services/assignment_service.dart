import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import '../models/assignment.dart';
import '../services/notification_service.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Add this line
  // Add cache for assignments
  final Map<String, List<Assignment>> _assignmentsCache = {};
  
  // Add a subject to broadcast assignment status changes
  final _assignmentStatusController = StreamController<void>.broadcast();
  
  // Expose the stream as a public property
  Stream<void> get onAssignmentStatusChanged => _assignmentStatusController.stream;

  Stream<List<Assignment>> getGroupAssignments(String groupId) {
    // First emit cached data if available
    List<Assignment>? cachedAssignments = _assignmentsCache[groupId];
    
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          // Use a map to deduplicate by ID
          final Map<String, Assignment> uniqueAssignments = {};
          
          for (var doc in snapshot.docs) {
            final assignment = Assignment.fromMap(
              doc.data(),
              id: doc.id,
              groupId: groupId,
            );
            
            uniqueAssignments[doc.id] = assignment;
          }
          
          final assignments = uniqueAssignments.values.toList();
          
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

  // Future<void> deleteAssignment({
  //   required String groupId,
  //   required String assignmentId,
  // }) async {
  //   // Create a batch to perform multiple operations atomically
  //   final batch = _firestore.batch();
    
  //   // Reference to the assignment document
  //   final assignmentRef = _firestore
  //       .collection('groups')
  //       .doc(groupId)
  //       .collection('assignments')
  //       .doc(assignmentId);
    
  //   // Add assignment deletion to batch
  //   batch.delete(assignmentRef);
    
  //   // Get all tasks for this assignment
  //   final taskSnapshot = await _firestore
  //       .collection('tasks')
  //       .where('assignmentId', isEqualTo: assignmentId)
  //       .get();
    
  //   // Add each task deletion to the batch
  //   for (var doc in taskSnapshot.docs) {
  //     batch.delete(doc.reference);
  //   }
    
  //   // Delete completion status documents
  //   final completionSnapshot = await _firestore
  //       .collection('completedAssignments')
  //       .where('assignmentId', isEqualTo: assignmentId)
  //       .get();
    
  //   // Add each completion document deletion to the batch
  //   for (var doc in completionSnapshot.docs) {
  //     batch.delete(doc.reference);
  //   }
    
  //   // Commit the batch operation
  //   await batch.commit();
    
  //   // Also update the cache
  //   if (_assignmentsCache.containsKey(groupId)) {
  //     _assignmentsCache[groupId] = _assignmentsCache[groupId]!
  //         .where((a) => a.id != assignmentId)
  //         .toList();
  //   }
    
  //   // Log the deletion for debugging
  //   print('Assignment $assignmentId deleted with all ${taskSnapshot.docs.length} associated tasks');
  // }

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
      
      // Create a local stream controller to emit optimistic updates
      final controller = StreamController<bool>();
      
      // Emit the expected state immediately
      controller.add(complete);
      
      if (complete) {
        // Mark as complete
        await docRef.set({
          'assignmentId': assignmentId,
          'userId': userId,
          'completedAt': FieldValue.serverTimestamp(),
        });
        
        // Also complete all incomplete tasks for this assignment
        // Get all tasks for this assignment that are not completed
        final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();
          
        // Update all tasks to be completed in a batch
        if (tasksSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          final now = Timestamp.now();
          
          for (final taskDoc in tasksSnapshot.docs) {
            batch.update(taskDoc.reference, {
              'isCompleted': true,
              'completedAt': now,
            });
          }
          
          await batch.commit();
          
          // Emit task completion events to update UI
          _assignmentStatusController.add(null);
          
          print('Completed ${tasksSnapshot.docs.length} tasks along with assignment');
        }
      } else {
        // Mark as incomplete by deleting the document
        await docRef.delete();
        
        // Also mark all completed tasks for this assignment as incomplete
        final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .get();
          
        // Update all tasks to be incomplete in a batch
        if (tasksSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          
          for (final taskDoc in tasksSnapshot.docs) {
            batch.update(taskDoc.reference, {
              'isCompleted': false,
              'completedAt': null,
            });
          }
          
          await batch.commit();
          
          // Emit task completion events to update UI
          _assignmentStatusController.add(null);
          
          print('Marked ${tasksSnapshot.docs.length} tasks as incomplete along with assignment');
        }
      }
      
      // Notify listeners about the status change
      _assignmentStatusController.add(null);
      
      // Close the controller
      controller.close();
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
  
  // Add this method to your AssignmentService class
  Future<void> checkCompletionStatusChange(String assignmentId, String userId) async {
    try {
      if (assignmentId.isEmpty || userId.isEmpty) {
        print('Invalid assignment ID or user ID');
        return;
      }
      
      // Get all tasks for this assignment directly from Firestore to ensure fresh data
      final tasksSnapshot = await _firestore
        .collection('tasks')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('userId', isEqualTo: userId)
        .get(); // Using get() for fresh data instead of cached snapshots

      final tasks = tasksSnapshot.docs.map((doc) => doc.data()).toList();
      
      // Debug print to track task status
      print('Checking completion status for assignment $assignmentId - Found ${tasks.length} tasks');
      tasks.forEach((task) {
        print('Task ${task['id']}: isCompleted = ${task['isCompleted']}');
      });
      
      // No tasks = not completed
      if (tasks.isEmpty) {
        await markAssignmentComplete(
          assignmentId: assignmentId,
          userId: userId,
          complete: false,
        );
        return;
      }

      // Check if all tasks are completed
      final allTasksCompleted = tasks.every((task) => task['isCompleted'] == true);
      
      // Mark assignment as complete only if all tasks are completed
      await markAssignmentComplete(
        assignmentId: assignmentId,
        userId: userId,
        complete: allTasksCompleted,
      );
      
      print('Assignment $assignmentId completion status updated to: $allTasksCompleted');
      
      // Force emit an event to make sure all UI elements update
      _assignmentStatusController.add(null);
    } catch (e) {
      print('Error checking assignment completion status: $e');
    }
  }
  
  // Add this method to your dispose method or app cleanup
  void dispose() {
    _assignmentStatusController.close();
  }

  Future<void> deleteAssignment(String assignmentId, String groupId) async {
    try {
      // Check if user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Proper error handling with specific messages
      try {
        // Delete the assignment document
        await _firestore.collection('groups') // Use _firestore instead of _db
            .doc(groupId)
            .collection('assignments')
            .doc(assignmentId)
            .delete();
        
        print('Successfully deleted assignment $assignmentId from group $groupId');
        
        // Also clean up any related tasks
        final taskSnapshot = await _firestore
            .collection('tasks')
            .where('assignmentId', isEqualTo: assignmentId)
            .get();
        
        // Delete tasks in a batch if there are any
        if (taskSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in taskSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          print('Deleted ${taskSnapshot.docs.length} related tasks');
        }
        
        // Clean up completion status documents
        final completionSnapshot = await _firestore
            .collection('completedAssignments')
            .where('assignmentId', isEqualTo: assignmentId)
            .get();
        
        if (completionSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in completionSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          print('Deleted ${completionSnapshot.docs.length} completion records');
        }
        
        // Update cache
        if (_assignmentsCache.containsKey(groupId)) {
          _assignmentsCache[groupId] = _assignmentsCache[groupId]!
              .where((a) => a.id != assignmentId)
              .toList();
        }
      } catch (e) {
        print('Error deleting assignment: $e');
        throw Exception('Failed to delete assignment: ${e.toString()}');
      }
    } catch (e) {
      print('Error in deleteAssignment: $e');
      rethrow;
    }
  }
}
