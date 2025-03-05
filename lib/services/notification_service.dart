import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/assignment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await Firebase.initializeApp();
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Schedule assignment checks
    _scheduleAssignmentChecks();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'assignment_reminder',
          'Assignment Reminder',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> updateUserToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  Future<void> subscribeToGroup(String groupId) async {
    await _messaging.subscribeToTopic('group_$groupId');
  }

  Future<void> unsubscribeFromGroup(String groupId) async {
    await _messaging.unsubscribeFromTopic('group_$groupId');
  }

  Future<void> sendAssignmentNotification({
    required String groupId,
    required String groupName,
    required String assignmentName,
    required String type, // 'new', 'upcoming', 'overdue'
  }) async {
    final users = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .get();

    for (var user in users.docs) {
      final userData = await _firestore
          .collection('users')
          .doc(user.id)
          .get();
      
      final token = userData.data()?['fcmToken'];
      if (token != null) {
        await _sendNotification(
          token: token,
          title: 'Assignment $type',
          body: _getNotificationBody(type, assignmentName, groupName),
        );
      }
    }
  }

  String _getNotificationBody(String type, String assignmentName, String groupName) {
    switch (type) {
      case 'new':
        return 'New assignment "$assignmentName" added to $groupName';
      case 'upcoming':
        return 'Assignment "$assignmentName" in $groupName is due soon';
      case 'overdue':
        return 'Assignment "$assignmentName" in $groupName is overdue';
      default:
        return '';
    }
  }

  Future<void> sendChatNotification({
    required String groupId,
    required String groupName,
    required String senderName,
    required String message,
  }) async {
    await _sendTopicNotification(
      topic: 'group_$groupId',
      title: groupName,
      body: '$senderName: $message',
    );
  }

  Future<void> sendGroupJoinNotification({
    required String groupId,
    required String groupName,
    required String userName,
  }) async {
    await _sendTopicNotification(
      topic: 'group_$groupId',
      title: groupName,
      body: '$userName joined the group',
    );
  }

  Future<void> _sendNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    await _firestore.collection('notifications').add({
      'token': token,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendTopicNotification({
    required String topic,
    required String title,
    required String body,
  }) async {
    await _firestore.collection('notifications').add({
      'topic': topic,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _scheduleAssignmentChecks() {
    // Check assignments daily
    Stream.periodic(const Duration(hours: 24)).listen((_) {
      _checkUpcomingAssignments();
      _checkOverdueAssignments();
    });
  }

  Future<void> _checkUpcomingAssignments() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final assignments = await _firestore
        .collectionGroup('assignments')
        .where('dueDate', isGreaterThan: now)
        .where('dueDate', isLessThan: tomorrow)
        .get();

    for (var doc in assignments.docs) {
      // Get the group ID from the reference path
      final groupId = doc.reference.parent.parent?.id ?? '';
      
      // Create assignment with required parameters
      final assignment = Assignment.fromMap(
        doc.data(),
        id: doc.id, // Add the missing id parameter
        groupId: groupId, // Add the missing groupId parameter
      );
      
      final groupSnapshot = await doc.reference.parent.parent?.get();
      if (groupSnapshot != null && groupSnapshot.exists) {
        final groupName = groupSnapshot.data()?['name'];
        await sendAssignmentNotification(
          groupId: groupSnapshot.id,
          groupName: groupName ?? 'Unknown Group',
          assignmentName: assignment.name,
          type: 'upcoming',
        );
      }
    }
  }

  Future<void> _checkOverdueAssignments() async {
    final now = DateTime.now();
    final assignments = await _firestore
        .collectionGroup('assignments')
        .where('dueDate', isLessThan: now)
        .where('notifiedOverdue', isEqualTo: false)
        .get();

    for (var doc in assignments.docs) {
      // Get the group ID from the reference path
      final groupId = doc.reference.parent.parent?.id ?? '';
      
      // Create assignment with required parameters
      final assignment = Assignment.fromMap(
        doc.data(),
        id: doc.id, // Add the missing id parameter
        groupId: groupId, // Add the missing groupId parameter
      );
      
      final groupSnapshot = await doc.reference.parent.parent?.get();
      if (groupSnapshot != null && groupSnapshot.exists) {
        final groupName = groupSnapshot.data()?['name'];
        await sendAssignmentNotification(
          groupId: groupSnapshot.id,
          groupName: groupName ?? 'Unknown Group',
          assignmentName: assignment.name,
          type: 'overdue',
        );
        // Mark as notified
        await doc.reference.update({'notifiedOverdue': true});
      }
    }
  }
}
