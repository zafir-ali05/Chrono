import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _imageUrlCache = {};

  // Upload profile image and return download URL
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Debug print to verify user is authenticated
      print('Uploading image for user: ${user.uid}');
      
      // Create a reference to the file location
      final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
      
      // Upload file with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': user.uid},
      );
      
      // Perform upload task
      final uploadTask = await ref.putFile(imageFile, metadata);
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Update user document with photoURL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'displayName': user.displayName ?? 'User',
            'email': user.email ?? '',
            'photoURL': downloadUrl,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      // Update auth user
      await user.updatePhotoURL(downloadUrl);
      
      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      throw Exception('Error uploading profile image: $e');
    }
  }
  
  // Get profile image URL for a user
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final ref = _storage.ref().child('profile_images/$userId.jpg');
      return await ref.getDownloadURL();
    } catch (e) {
      // Return null if image doesn't exist or there was an error
      return null;
    }
  }
  
  // Delete profile image
  Future<void> deleteProfileImage(String userId) async {
    try {
      final ref = _storage.ref().child('profile_images/$userId.jpg');
      await ref.delete();
    } catch (e) {
      // Ignore errors if file doesn't exist
      print('Error deleting profile image: $e');
    }
  }

  // Add this new method to your StorageService class
  Future<String?> uploadGroupImage(String groupId, File imageFile) async {
    try {
      // Get current user to verify authentication
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Create a reference to the file location
      final ref = _storage.ref().child('group_images/$groupId.jpg');
      
      // Upload file with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'groupId': groupId,
          'uploadedBy': user.uid,
        },
      );
      
      // Perform upload task
      final uploadTask = await ref.putFile(imageFile, metadata);
      
      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Update group document with the image URL
      await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .update({'imageUrl': downloadUrl});
        
      // Update cache
      _imageUrlCache[groupId] = downloadUrl;
      
      print('Group image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading group image: $e');
      throw Exception('Error uploading group image: $e');
    }
  }

  // Add method to get group image URL
  Future<String?> getGroupImageUrl(String groupId) async {
    // Check if URL is in cache first
    if (_imageUrlCache.containsKey(groupId)) {
      return _imageUrlCache[groupId];
    }
    
    try {
      final ref = _storage.ref().child('group_images/$groupId.jpg');
      final url = await ref.getDownloadURL();
      
      // Store in cache
      _imageUrlCache[groupId] = url;
      return url;
    } catch (e) {
      // URL not found, cache as null to avoid repeated failed lookups
      return null;
    }
  }
}
