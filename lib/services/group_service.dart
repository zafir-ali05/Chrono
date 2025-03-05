import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class GroupService {
  final CollectionReference _groupsCollection = 
      FirebaseFirestore.instance.collection('groups');
  final CollectionReference _assignmentsCollection = 
      FirebaseFirestore.instance.collection('assignments');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Group> createGroup(String name, String creatorId) async {
    // Generate a unique 6-character code
    String groupId = randomAlphaNumeric(6).toUpperCase();
    
    // Ensure the code is unique
    while ((await _groupsCollection.doc(groupId).get()).exists) {
      groupId = randomAlphaNumeric(6).toUpperCase();
    }

    final group = Group(
      id: groupId,
      name: name,
      creatorId: creatorId,
      members: [creatorId],
      createdAt: DateTime.now(),
    );

    await _groupsCollection.doc(groupId).set(group.toMap());
    return group;
  }

  Future<void> createGroupFromModel(Group group) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Create the group in the main groups collection
      await _groupsCollection.doc(group.id).set({
        ...group.toMap(),
        'creatorId': userId,
        'members': [userId], // Store as array instead of map
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add reference to user's groups collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(group.id)
          .set({
        'groupId': group.id,
        'name': group.name,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  Future<Group?> joinGroup(String groupId, String userId) async {
    final docSnapshot = await _groupsCollection.doc(groupId).get();
    
    if (!docSnapshot.exists) {
      throw Exception('Group not found');
    }

    final groupData = docSnapshot.data() as Map<String, dynamic>;
    final group = Group.fromMap(groupData);

    if (group.members.contains(userId)) {
      throw Exception('You are already a member of this group');
    }

    final updatedMembers = [...group.members, userId];
    await _groupsCollection.doc(groupId).update({'members': updatedMembers});

    return Group.fromMap({
      ...groupData,
      'members': updatedMembers,
    });
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      // First get the group to check if user is the last member
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      // Cast the data to Map<String, dynamic>
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final currentMembers = List<String>.from(groupData['members'] ?? []);
      
      if (!currentMembers.contains(userId)) {
        throw Exception('You are not a member of this group');
      }

      currentMembers.remove(userId);

      // If this is the last member, delete the group and its subcollections
      if (currentMembers.isEmpty) {
        await _deleteGroupSubcollections(groupId);
        await _groupsCollection.doc(groupId).delete();
      } else {
        // Otherwise just update members
        await _groupsCollection.doc(groupId).update({
          'members': currentMembers,
        });
      }
    } catch (e) {
      print('Error leaving group: $e');
      rethrow;
    }
  }

  Future<void> _deleteGroupSubcollections(String groupId) async {
    try {
      // Delete messages subcollection
      final messagesQuery = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .get();
      
      for (var doc in messagesQuery.docs) {
        await doc.reference.delete();
      }

      // Delete assignments subcollection
      final assignmentsQuery = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('assignments')
          .get();
      
      for (var doc in assignmentsQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting subcollections: $e');
      rethrow;
    }
  }

  Stream<List<Group>> getUserGroups(String userId) {
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }

    return _groupsCollection
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            try {
              return Group.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              });
            } catch (e) {
              print('Error parsing group data: $e');
              return null;
            }
          })
          .where((group) => group != null)
          .cast<Group>()
          .toList();
        });
  }

  Stream<List<Group>> getUserGroupsFromUser() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('groups')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Group.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
  }) async {
    try {
      // Update the group in Firestore
      await _groupsCollection.doc(groupId).update({
        'name': name,
      });
    } catch (e) {
      print('Error updating group: $e');
      rethrow;
    }
  }

  Stream<List<String>> getGroupMemberNames(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<String> names = [];
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        final userName = userDoc.data()?['displayName'] as String? ?? 'Unknown User';
        names.add(userName);
      }
      return names;
    });
  }

  Stream<List<Map<String, dynamic>>> getGroupMembers(String groupId) {
    // Add print for debugging
    print('Fetching members for group: $groupId');
    
    return _groupsCollection
        .doc(groupId)
        .snapshots()
        .asyncMap((groupDoc) async {
      if (!groupDoc.exists) {
        print('Group document does not exist');
        return [];
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      
      // Ensure we extract the members as a List<dynamic> then cast to String
      final membersList = groupData['members'];
      if (membersList == null || membersList is! List) {
        print('Members list is null or not a List: $membersList');
        return [];
      }
      
      final List<String> memberIds = membersList.cast<String>();
      print('Found ${memberIds.length} member IDs'); // Debug print

      final List<Map<String, dynamic>> memberDetails = [];
      
      // Fetch user details for each member ID
      for (String memberId in memberIds) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(memberId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            memberDetails.add({
              'uid': memberId,
              'displayName': userData['displayName'] ?? 'User ${memberDetails.length + 1}',
              'email': userData['email'] ?? '',
              'isOwner': memberId == groupData['creatorId'],
            });
            print('Added member: ${userData['displayName']}');
          } else {
            print('User document not found for ID: $memberId');
            // Add placeholder for users that don't exist anymore
            memberDetails.add({
              'uid': memberId,
              'displayName': 'User ${memberDetails.length + 1}',
              'email': '',
              'isOwner': memberId == groupData['creatorId'],
            });
          }
        } catch (e) {
          print('Error fetching user details for $memberId: $e');
          // Still add a placeholder
          memberDetails.add({
            'uid': memberId,
            'displayName': 'User ${memberDetails.length + 1}',
            'email': '',
            'isOwner': memberId == groupData['creatorId'],
          });
        }
      }

      print('Returning ${memberDetails.length} member details'); // Debug print
      return memberDetails;
    });
  }
}
