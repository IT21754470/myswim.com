import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swimming_app/services/training_session_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/user_profile.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's profile from Firestore
  // In your ProfileService.dart, make sure this is consistent:
static Future<UserProfile?> getUserProfile() async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      return null;
    }

    print('✅ Getting profile for user: ${user.uid}');
    final doc = await _firestore
        .collection('profiles') // ✅ Make sure this matches everywhere
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      print('✅ Profile loaded successfully: ${doc.data()}');
      return UserProfile.fromMap(doc.data()!);
    }

    print('⚠️ No profile document found, creating default...');
    
    // ✅ Create and save default profile immediately
    final defaultProfile = UserProfile(
      name: user.displayName ?? user.email?.split('@')[0] ?? 'Swimmer',
      gender: 'Male',
      totalSessions: 0,
      totalDistance: 0.0,
      totalHours: 0,
      createdAt: DateTime.now(),
    );
    
    await saveUserProfile(defaultProfile);
    return defaultProfile;
    
  } catch (e) {
    print('❌ Error getting user profile: $e');
    return null;
  }
}

// Add this to ProfileService
static Future<void> syncProfileStats() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get actual sessions from database
    final sessions = await TrainingSessionService.getUserTrainingSessions();
    
    // Calculate actual stats
    final actualSessionCount = sessions.length;
    final actualTotalDistance = sessions.fold<double>(0, (sum, session) => 
        sum + (session.trainingDistance / 1000)); // Convert to km
    final actualTotalHours = sessions.fold<int>(0, (sum, session) => 
        sum + (session.sessionDuration / 60).round()); // Convert to hours

    // Get existing profile
    var profile = await getUserProfile();
    if (profile == null) {
      // Create new profile with correct stats
      profile = UserProfile(
        name: user.displayName ?? user.email?.split('@')[0] ?? 'Swimmer',
        gender: 'Male',
        totalSessions: actualSessionCount,
        totalDistance: actualTotalDistance,
        totalHours: actualTotalHours,
        createdAt: DateTime.now(),
      );
    } else {
      // Update existing profile with correct stats
      profile = profile.copyWith(
        totalSessions: actualSessionCount,
        totalDistance: actualTotalDistance,
        totalHours: actualTotalHours,
        updatedAt: DateTime.now(),
      );
    }

    await saveUserProfile(profile);
    print('✅ Profile stats synced: $actualSessionCount sessions');
  } catch (e) {
    print('❌ Error syncing profile stats: $e');
  }
}
  // Save user profile to Firestore
  static Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('💾 Saving profile for user: ${user.uid}');
      await _firestore
          .collection('profiles')
          .doc(user.uid)
          .set(profile.toMap(), SetOptions(merge: true));

      print('✅ Profile saved successfully');
    } catch (e) {
      print('❌ Error saving user profile: $e');
      throw Exception('Failed to save profile: $e');
    }
  }

  // Test Firestore connection (replaces Firebase Storage test)
  // In ProfileService class
static Future<bool> testFirebaseSetup() async {
  try {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user for Firestore test');
      return false;
    }

    print('🧪 Testing basic Firestore connection...');
    
    // Simple test - just try to get server timestamp
    await _firestore.doc('test/connection').set({
      'timestamp': FieldValue.serverTimestamp(),
      'test': true,
    });
    
    print('✅ Firestore write test successful');
    
    // Read it back
    final doc = await _firestore.doc('test/connection').get();
    if (doc.exists) {
      print('✅ Firestore read test successful');
      
      // Clean up
      await _firestore.doc('test/connection').delete();
      print('✅ Firestore cleanup successful');
      
      return true;
    }
    
    return false;
    
  } on FirebaseException catch (e) {
    print('❌ Firebase Exception: ${e.code} - ${e.message}');
    if (e.code == 'permission-denied') {
      print('❌ Permission denied. Check Firestore security rules.');
    } else if (e.code == 'unavailable') {
      print('❌ Firestore not available. Make sure it\'s enabled in Firebase Console.');
    }
    return false;
  } catch (e) {
    print('❌ General Firestore test error: $e');
    return false;
  }
}

  // Convert image to base64 and store in Firestore
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Starting image processing for user: ${user.uid}');
      print('📂 File path: ${imageFile.path}');

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      // Check file size (limit to 1MB for base64 storage)
      final fileSize = await imageFile.length();
      print('📏 File size: ${fileSize / 1024 / 1024} MB');
      
      if (fileSize > 1 * 1024 * 1024) {
        throw Exception('Image file too large. Please select an image under 1MB.');
      }

      print('🔄 Converting image to base64...');
      
      // Read file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Convert to base64
      final String base64Image = base64Encode(imageBytes);
      
      // Create data URL (includes image type)
      final String imageDataUrl = 'data:image/jpeg;base64,$base64Image';
      
      print('✅ Image converted to base64 successfully');
      print('📊 Base64 size: ${base64Image.length} characters');
      
      // Store in Firestore
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _firestore
          .collection('profile_images')
          .doc(user.uid)
          .set({
        'imageData': imageDataUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'filename': 'profile_${user.uid}_$timestamp.jpg',
        'size': fileSize,
      });
      
      print('✅ Image stored in Firestore successfully');
      
      // Return the data URL to be used as profileImageUrl
      return imageDataUrl;
      
    } catch (e) {
      print('❌ Error processing image: $e');
      throw Exception('Failed to process image: $e');
    }
  }

  // Delete old profile image from Firestore
  static Future<void> deleteProfileImage(String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Only delete if it's a base64 image stored in our system
      if (imageUrl.startsWith('data:image/')) {
        print('🗑️ Deleting old profile image from Firestore');
        await _firestore
            .collection('profile_images')
            .doc(user.uid)
            .delete();
        print('✅ Old profile image deleted successfully');
      }
    } catch (e) {
      print('⚠️ Warning: Could not delete old profile image: $e');
      // Don't throw error - it's not critical if old image deletion fails
    }
  }

  // Update profile stats (for swimming sessions)
  static Future<void> updateProfileStats({
    int? additionalSessions,
    double? additionalDistance,
    int? additionalHours,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = _firestore.collection('profiles').doc(user.uid);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (snapshot.exists) {
          final data = snapshot.data()!;
          final currentProfile = UserProfile.fromMap(data);
          
          final updatedProfile = currentProfile.copyWith(
            totalSessions: currentProfile.totalSessions + (additionalSessions ?? 0),
            totalDistance: currentProfile.totalDistance + (additionalDistance ?? 0.0),
            totalHours: currentProfile.totalHours + (additionalHours ?? 0),
          );
          
          transaction.update(docRef, updatedProfile.toMap());
        }
      });
    } catch (e) {
      print('❌ Error updating profile stats: $e');
      throw Exception('Failed to update stats: $e');
    }
  }

  // Clear user profile (for logout)
  static Future<void> clearUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🔄 User logged out - profile data remains in Firestore');
    } catch (e) {
      print('❌ Error during profile cleanup: $e');
    }
  }

  // Listen to profile changes in real-time
  static Stream<UserProfile?> getUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('profiles')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return UserProfile.fromMap(snapshot.data()!);
          }
          return null;
        });
  }

  // Helper: Check if image is base64 data URL
  static bool isBase64Image(String? imageUrl) {
    return imageUrl != null && imageUrl.startsWith('data:image/');
  }

  // Helper: Get file extension from base64 data URL
  static String getImageExtension(String dataUrl) {
    if (dataUrl.contains('data:image/jpeg')) return 'jpg';
    if (dataUrl.contains('data:image/png')) return 'png';
    if (dataUrl.contains('data:image/gif')) return 'gif';
    return 'jpg'; // default
  }
}