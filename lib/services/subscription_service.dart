// lib/services/subscription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user is pro
  static Future<bool> isProUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final profile = UserProfile.fromMap(doc.data()!);
      return profile.isProActive;
    } catch (e) {
      print('Error checking pro status: $e');
      return false;
    }
  }

  // Upgrade to Pro
  static Future<bool> upgradeToPro({
    required String subscriptionType,
    required String paymentMethod,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      DateTime? expiryDate;
      if (subscriptionType == 'monthly') {
        expiryDate = DateTime.now().add(Duration(days: 30));
      } else if (subscriptionType == 'yearly') {
        expiryDate = DateTime.now().add(Duration(days: 365));
      }
      // lifetime has no expiry

      await _firestore.collection('users').doc(userId).update({
        'isPro': true,
        'proExpiryDate': expiryDate?.toIso8601String(),
        'subscriptionType': subscriptionType,
        'paymentMethod': paymentMethod,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Log subscription in separate collection
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'subscriptionType': subscriptionType,
        'paymentMethod': paymentMethod,
        'startDate': DateTime.now().toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error upgrading to pro: $e');
      return false;
    }
  }

  // Get subscription details
  static Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'isPro': data['isPro'] ?? false,
        'subscriptionType': data['subscriptionType'],
        'proExpiryDate': data['proExpiryDate'],
        'paymentMethod': data['paymentMethod'],
      };
    } catch (e) {
      print('Error getting subscription details: $e');
      return null;
    }
  }

  // Cancel subscription
  static Future<bool> cancelSubscription() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'isPro': false,
        'proExpiryDate': null,
        'subscriptionType': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error canceling subscription: $e');
      return false;
    }
  }
}