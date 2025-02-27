import 'package:cloud_firestore/cloud_firestore.dart';

class Assignment {
  final String id;
  final String groupId;
  final String className;
  final String name;
  final DateTime dueDate;
  final DateTime createdAt;
  final String creatorId;

  Assignment({
    required this.id,
    required this.groupId,
    required this.className,
    required this.name,
    required this.dueDate,
    required this.createdAt,
    required this.creatorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'className': className,
      'name': name,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'creatorId': creatorId,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map, {String? id, String? groupId}) {
    try {
      print("Parsing assignment with data: $map"); // Debug print
      final assignment = Assignment(
        id: id ?? map['id'] ?? '',
        groupId: groupId ?? map['groupId'] ?? '',
        className: map['className'] ?? '',
        name: map['name'] ?? '',
        dueDate: _parseDateTime(map['dueDate']) ?? DateTime.now(),
        createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
        creatorId: map['creatorId'] ?? '',
      );
      print("Successfully parsed assignment: ${assignment.name}"); // Debug print
      return assignment;
    } catch (e) {
      print("Error creating Assignment from map: $e"); // Debug print
      rethrow;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    throw FormatException('Invalid datetime format: $value');
  }
}
