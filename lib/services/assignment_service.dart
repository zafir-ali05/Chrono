import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment.dart';
import 'package:random_string/random_string.dart';
import 'package:rxdart/rxdart.dart';

class AssignmentService {
  final CollectionReference _assignmentsCollection =
      FirebaseFirestore.instance.collection('assignments');
  final CollectionReference _groupsCollection =
      FirebaseFirestore.instance.collection('groups');

  Future<Assignment> createAssignment({
    required String groupId,
    required String className,
    required String name,
    required DateTime dueDate,
    required String creatorId,
  }) async {
    final String assignmentId = randomAlphaNumeric(20);

    final assignment = Assignment(
      id: assignmentId,
      groupId: groupId,
      className: className,
      name: name,
      dueDate: dueDate,
      createdAt: DateTime.now(),
      creatorId: creatorId,
    );

    await _assignmentsCollection.doc(assignmentId).set(assignment.toMap());
    return assignment;
  }

  Stream<List<Assignment>> getGroupAssignments(String groupId) {
    return _assignmentsCollection
        .where('groupId', isEqualTo: groupId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Stream<List<Assignment>> getUserAssignments(String userId) {
    return _groupsCollection
        .where('members', arrayContains: userId)
        .snapshots()
        .switchMap((groupSnapshot) {
      final groupIds = groupSnapshot.docs.map((doc) => doc.id).toList();
      
      if (groupIds.isEmpty) {
        return Stream.value([]);
      }

      return _assignmentsCollection
          .where('groupId', whereIn: groupIds)
          .orderBy('dueDate')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Assignment.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    });
  }
}
