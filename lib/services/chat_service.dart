import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Message>> getMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure timestamp exists
            if (data['timestamp'] == null) {
              data['timestamp'] = Timestamp.now();
            }
            return Message.fromMap(data, doc.id);
          }).toList();
        });
  }

  Future<void> sendMessage(
    String groupId,
    String senderId,
    String senderName,
    String content,
  ) async {
    try {
      // Add message to Firestore
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Message sent successfully"); // Debug print

      // Get group name for notification
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();
      
      final groupName = groupDoc.data()?['name'] ?? 'Unknown Group';

      // Send notification
      final notificationService = NotificationService();
      await notificationService.sendChatNotification(
        groupId: groupId,
        groupName: groupName,
        senderName: senderName,
        message: content,
      );
    } catch (e) {
      print("Error sending message: $e"); // Debug print
      rethrow;
    }
  }
}
