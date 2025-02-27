import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String name) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Update the user's display name
    await userCredential.user?.updateDisplayName(name);
    
    return userCredential;
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
}
