import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import 'package:rxdart/rxdart.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Replace with a more specific task event
  final _taskCompletionController = BehaviorSubject<TaskCompletionEvent>();
  
  // Expose a more specific stream
  Stream<TaskCompletionEvent> get onTaskStatusChanged => _taskCompletionController.stream;

  // Add this new method to get a stream for a specific task's status
  Stream<bool> getTaskCompletionStatus(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          return doc.data()?['isCompleted'] ?? false;
        });
  }

  Stream<List<Task>> getTasksForAssignment(String assignmentId, String userId) {
    return _firestore
        .collection('tasks')
        .where('assignmentId', isEqualTo: assignmentId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Task.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Stream<List<Task>> getUserTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Task.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<void> createTask(Task task) async {
    await _firestore.collection('tasks').add(task.toMap());
  }

  // Modify to emit more specific events
  Future<void> updateTask(Task task) async {
    await _firestore
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());
        
    // Emit an event with specific task details
    _taskCompletionController.add(
      TaskCompletionEvent(
        taskId: task.id,
        assignmentId: task.assignmentId,
        isCompleted: task.isCompleted
      )
    );
  }

  Future<void> deleteTask(String taskId) async {
    try {
      // Get the task data before deleting it
      final docSnapshot = await _firestore.collection('tasks').doc(taskId).get();
      String assignmentId = '';
      
      // Extract the assignmentId if the document exists
      if (docSnapshot.exists && docSnapshot.data() != null) {
        assignmentId = docSnapshot.data()!['assignmentId'] ?? '';
      }
      
      // Delete the task
      await _firestore.collection('tasks').doc(taskId).delete();
      
      // Now emit a complete event with all required parameters
      _taskCompletionController.add(
        TaskCompletionEvent(
          taskId: taskId,
          assignmentId: assignmentId, 
          isCompleted: false
        )
      );
    } catch (e) {
      print('Error deleting task: $e');
      throw e;
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final newCompletionStatus = !task.isCompleted;
    final updatedTask = task.copyWith(
      isCompleted: newCompletionStatus,
      completedAt: newCompletionStatus ? DateTime.now() : null,
    );
    
    // Emit the event before actually updating the database
    // This provides an "optimistic UI" update
    _taskCompletionController.add(
      TaskCompletionEvent(
        taskId: task.id,
        assignmentId: task.assignmentId, 
        isCompleted: newCompletionStatus
      )
    );
    
    // Then update the database
    await updateTask(updatedTask);
  }
  
  // Add a method to update multiple tasks' completion status at once
  Future<void> batchUpdateTasksCompletion(
    String assignmentId, 
    String userId, 
    bool completionStatus
  ) async {
    try {
      // Get all tasks for this assignment by this user
      final querySnapshot = await _firestore
          .collection('tasks')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isNotEqualTo: completionStatus)
          .get();
      
      if (querySnapshot.docs.isEmpty) return;
      
      // Create a batch operation
      final batch = _firestore.batch();
      final now = DateTime.now();
      final timestamp = completionStatus ? Timestamp.fromDate(now) : null;
      
      // Update all matching tasks
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isCompleted': completionStatus,
          'completedAt': timestamp,
        });
      }
      
      // Commit the batch
      await batch.commit();
      
      // Emit a single event for the assignment since all tasks were updated
      _taskCompletionController.add(
        TaskCompletionEvent(
          taskId: 'batch-update',
          assignmentId: assignmentId,
          isCompleted: completionStatus
        )
      );
      
      print('Batch updated ${querySnapshot.docs.length} tasks for assignment $assignmentId');
    } catch (e) {
      print('Error in batch updating tasks: $e');
      throw e;
    }
  }
  
  // Add method to dispose resources
  void dispose() {
    _taskCompletionController.close();
  }
}

// Create a more detailed event class
class TaskCompletionEvent {
  final String taskId;
  final String assignmentId;
  final bool isCompleted;
  
  TaskCompletionEvent({
    required this.taskId,
    required this.assignmentId,
    required this.isCompleted,
  });
}

Future<void> clearTaskCache() async {
  await FirebaseFirestore.instance.clearPersistence();
}
