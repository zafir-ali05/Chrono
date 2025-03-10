import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:flutter/material.dart';
//import 'package:flutter/cupertino.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache of user profiles
  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Sync user data to Firestore
      await syncUserToFirestore();
      
      return userCredential;
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update the user's display name
      await userCredential.user?.updateDisplayName(name);
      
      // Force reload to get updated user info
      await userCredential.user?.reload();
      
      // Sync user data to Firestore
      await syncUserToFirestore();
      
      return userCredential;
    } catch (e) {
      print('Error registering: $e');
      throw e;
    }
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with the credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get credentials for reauthentication
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      // Reauthenticate
      await user.reauthenticateWithCredential(credential);
      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      } else {
        throw Exception(e.message ?? 'Failed to change password');
      }
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      
      // Now sync the updated data to Firestore
      await syncUserToFirestore();
      
    } catch (e) {
      print('Error updating profile: $e');
      throw e;
    }
  }

  // Method to get user profile data
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    // If this is the current user, return their data
    if (_auth.currentUser?.uid == userId) {
      final user = _auth.currentUser!;
      return {
        'uid': user.uid,
        'displayName': user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
      };
    }
    
    // If we have cached data, return it
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }
    
    // Try to get from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final userData = {
          'uid': userId,
          'displayName': doc.data()?['displayName'] ?? 'User',
          'email': doc.data()?['email'] ?? '',
          'photoURL': doc.data()?['photoURL'] ?? '',
        };
        _userProfileCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print('Error fetching user data from Firestore: $e');
    }
    
    // Default placeholder data
    return {
      'uid': userId,
      'displayName': 'User',
      'email': '',
      'photoURL': '',
    };
  }

  // Add this to your AuthService class 
  Future<void> syncUserToFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Create or update a document in the 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('User profile synced to Firestore');
    } catch (e) {
      print('Error syncing user to Firestore: $e');
    }
  }

  // Add this method to manually sync a specific user when needed
  Future<void> syncProfileToFirestore(String userId, String displayName, String? email, String? photoURL) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'uid': userId,
        'displayName': displayName,
        'email': email ?? '',
        'photoURL': photoURL ?? '',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('User profile data synced to Firestore for user: $userId');
    } catch (e) {
      print('Error syncing specific user profile to Firestore: $e');
    }
  }
}
