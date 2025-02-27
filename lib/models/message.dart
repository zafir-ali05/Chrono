class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'],
      senderName: data['senderName'],
      content: data['content'],
      timestamp: (data['timestamp'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp,
    };
  }
}
