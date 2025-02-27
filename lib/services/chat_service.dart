import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../services/notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Message>> getMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(
    String groupId,
    String senderId,
    String senderName,
    String content,
  ) async {
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

    // Get group name for notification
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupName = groupDoc.data()?['name'];

    // Send notification for new message
    final notificationService = NotificationService();
    await notificationService.sendChatNotification(
      groupId: groupId,
      groupName: groupName ?? 'Unknown Group',
      senderName: senderName,
      message: content,
    );
  }
}
