import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Sends feedback by storing it in Firestore
  /// This will trigger a Cloud Function to email you
  Future<void> sendFeedback({
    required String message,
    String? name,
    String? email,
  }) async {
    try {
      // Check if user is logged in
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to send feedback.');
      }
      
      // Get user info if not provided
      final userEmail = email ?? user.email ?? '';
      final userName = name ?? user.displayName ?? '';
      
      // Create a document in the "feedback" collection
      // This will trigger a Cloud Function to send an email
      await _firestore.collection('feedback').add({
        'message': message,
        'name': userName,
        'email': userEmail,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return;
    } catch (e) {
      throw Exception('Failed to send feedback: ${e.toString()}');
    }
  }
}
