// ignore_for_file: unused_import, unused_element, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await result.user?.updateDisplayName(name);
      
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Google Sign-In
 Future<User?> signInWithGoogle() async {
  try {
    print('🔍 Starting Google Sign-In...');
    
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    
    if (googleUser == null) {
      print('❌ Google Sign-In cancelled by user');
      return null;
    }
    
    print('✅ Google user: ${googleUser.email}');
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    print('✅ Created Firebase credential');
    
    // Sign in to Firebase
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCredential.user;
    
    if (user != null) {
      print('✅ Firebase sign-in successful: ${user.email}');
      
      // ✅ Create/update user profile for Google users
      await _createOrUpdateUserProfile(user, googleUser.displayName ?? 'Google User');
      
      return user;
    }
    
    return null;
    
  } catch (e) {
    print('❌ Detailed error: $e');
    print('❌ Error type: ${e.runtimeType}');
    
    // ✅ Check if user was actually signed in despite the error
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('✅ User was signed in successfully despite plugin error');
      
      // Create profile if it doesn't exist
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (!doc.exists) {
          await _createOrUpdateUserProfile(
            currentUser, 
            currentUser.displayName ?? 'Google User'
          );
        }
      } catch (profileError) {
        print('❌ Profile creation error: $profileError');
      }
      
      return currentUser;
    }
    
    // If it's the PigeonUserDetails error but user is signed in, ignore it
    if (e.toString().contains('PigeonUserDetails')) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('✅ Ignoring PigeonUserDetails error - user is signed in');
        return user;
      }
    }
    
    rethrow;
  }
}

// ✅ Add this helper method to create user profiles
Future<void> _createOrUpdateUserProfile(User user, String displayName) async {
  try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    
    // Check if profile exists
    final docSnapshot = await userDoc.get();
    
    if (!docSnapshot.exists) {
      print('✅ Creating new user profile for: ${user.email}');
      
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
        'authProvider': 'google',
        // Add default swimming profile data
        'swimmingLevel': 'beginner',
        'preferredStroke': 'freestyle',
        'goals': [],
        'achievements': [],
      });
      
      print('✅ User profile created successfully');
    } else {
      // Update last sign in
      await userDoc.update({
        'lastSignIn': FieldValue.serverTimestamp(),
      });
      print('✅ User profile updated');
    }
  } catch (e) {
    print('❌ Error creating/updating user profile: $e');
    // Don't throw - let the auth succeed even if profile creation fails
  }
}
  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Check if user signed in with Google
  bool isGoogleUser() {
    final user = _auth.currentUser;
    if (user != null) {
      return user.providerData.any((info) => info.providerId == 'google.com');
    }
    return false;
  }

  // Helper method to create user profile for Google sign-in
  Future<void> _createUserProfile(User user) async {
    try {
      print('Creating profile for Google user: ${user.displayName}');
      // Add your profile creation logic here
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}