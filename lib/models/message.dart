import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:flutter/material.dart';
//import 'package:flutter/cupertino.dart';

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
    try {
      final timestamp = data['timestamp'];
      return Message(
        id: id,
        senderId: data['senderId'] ?? '',
        senderName: data['senderName'] ?? 'Unknown',
        content: data['content'] ?? '',
        timestamp: timestamp is Timestamp 
            ? timestamp.toDate() 
            : (timestamp ?? DateTime.now()),
      );
    } catch (e) {
      print("Error creating Message from map: $e"); // Debug print
      rethrow;
    }
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
