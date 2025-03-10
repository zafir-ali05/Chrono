import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:flutter/material.dart';
//import 'package:flutter/cupertino.dart';

class Assignment {
  final String id;
  final String groupId;
  final String className;
  final String name;
  final DateTime dueDate;
  final String creatorId;
  final DateTime createdAt;
  final bool notifiedOverdue;
  bool isCompleted = false;

  Assignment({
    required this.id,
    required this.groupId,
    required this.className,
    required this.name,
    required this.dueDate,
    required this.creatorId,
    required this.createdAt,
    this.notifiedOverdue = false,
  });

  factory Assignment.fromMap(Map<String, dynamic> map, {required String id, required String groupId}) {
    // Handle potential null values in the map
    try {
      final timestamp = map['dueDate'];
      final DateTime dueDate;
      
      if (timestamp is Timestamp) {
        dueDate = timestamp.toDate();
      } else {
        // Default to current date if dueDate is missing or invalid
        dueDate = DateTime.now();
        print('Warning: Invalid dueDate for assignment $id, using current date as fallback');
      }
      
      final createdTimestamp = map['createdAt'];
      final DateTime createdAt;
      
      if (createdTimestamp is Timestamp) {
        createdAt = createdTimestamp.toDate();
      } else {
        // Default to current date if createdAt is missing
        createdAt = DateTime.now();
      }
      
      return Assignment(
        id: id,
        groupId: groupId,
        className: map['className'] ?? 'Unnamed Class',
        name: map['name'] ?? 'Untitled Assignment',
        dueDate: dueDate,
        creatorId: map['creatorId'] ?? '',
        createdAt: createdAt,
        notifiedOverdue: map['notifiedOverdue'] ?? false,
      );
    } catch (e) {
      print('Error creating assignment from map: $e');
      print('Problematic map: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'name': name,
      'dueDate': Timestamp.fromDate(dueDate),
      'creatorId': creatorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'notifiedOverdue': notifiedOverdue,
    };
  }
}
