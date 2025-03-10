//import 'package:flutter/material.dart';
//import 'package:flutter/cupertino.dart';

class Group {
  final String id;
  final String name;
  final String creatorId;
  final List<String> members;
  final DateTime createdAt;
  final String? imageUrl; // Add this field

  Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.members,
    required this.createdAt,
    this.imageUrl, // Add this parameter
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'members': members,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl, // Add this field
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      creatorId: map['creatorId'],
      members: List<String>.from(map['members']),
      createdAt: DateTime.parse(map['createdAt']),
      imageUrl: map['imageUrl'], // Add this field
    );
  }
}
