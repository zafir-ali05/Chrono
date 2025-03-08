import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import 'package:rxdart/rxdart.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Improve the event controller to pass the completion state
  final _taskCompletionController = BehaviorSubject<TaskCompletionEvent>();
  
  // Expose a more descriptive stream for listeners
  Stream<TaskCompletionEvent> get onTaskStatusChanged => _taskCompletionController.stream;

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

  Future<void> updateTask(Task task) async {
    await _firestore
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
    // Emit an event to update counters (treat deletion like marking incomplete)
    _taskCompletionController.add(TaskCompletionEvent(isCompleted: false));
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final newCompletionStatus = !task.isCompleted;
    final updatedTask = task.copyWith(
      isCompleted: newCompletionStatus,
      completedAt: newCompletionStatus ? DateTime.now() : null,
    );
    await updateTask(updatedTask);
    
    // Emit event with the new status to notify listeners
    _taskCompletionController.add(TaskCompletionEvent(isCompleted: newCompletionStatus));
  }
  
  // Add method to dispose resources
  void dispose() {
    _taskCompletionController.close();
  }
}

// Create a more descriptive event class
class TaskCompletionEvent {
  final bool isCompleted;
  
  TaskCompletionEvent({required this.isCompleted});
}

Future<void> clearTaskCache() async {
  await FirebaseFirestore.instance.clearPersistence();
}
