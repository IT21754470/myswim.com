// ignore_for_file: unused_import, avoid_print, use_rethrow_when_possible, avoid_types_as_parameter_names

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swimming_app/models/user_profile.dart';
import '../models/training_session.dart';
import '../services/profile_service.dart';

class TrainingSessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _trainingSessions = 'training_sessions';

  /// ✅ FIXED: Get all training sessions with proper Timestamp handling
  static Future<List<TrainingSession>> getUserTrainingSessions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return [];
      }

      print('🔍 Fetching training sessions for user: ${user.uid}');

      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection(_trainingSessions)
            .where('userId', isEqualTo: user.uid)
            .get();
      } catch (e) {
        print('❌ Main query failed: $e');
        return await _tryAlternativeQueries();
      }

      print('✅ Found ${querySnapshot.docs.length} raw documents');
      
      if (querySnapshot.docs.isEmpty) {
        print('ℹ️ No sessions found, trying alternative queries...');
        return await _tryAlternativeQueries();
      }

      // ✅ FIXED: Better data processing with Timestamp handling
      final sessions = <TrainingSession>[];
      int validCount = 0;
      int invalidCount = 0;
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // ✅ Don't log raw data to avoid Timestamp JSON errors
          print('📄 Processing document ${doc.id}');
          
          // ✅ FIXED: Validate with proper field checking
          if (_isValidSessionData(data)) {
            final session = TrainingSession.fromFirestore(data, doc.id);
            sessions.add(session);
            validCount++;
            print('✅ Session ${doc.id} parsed successfully');
            print('   - Date: ${session.date}');
            print('   - Stroke: ${session.strokeType}');
            print('   - Distance: ${session.trainingDistance}m');
            print('   - Time: ${session.actualTime}s');
          } else {
            invalidCount++;
            print('❌ Session ${doc.id} is invalid');
            // ✅ Better field validation logging
            _logValidationErrors(data);
          }
        } catch (e) {
          invalidCount++;
          print('❌ Error parsing session ${doc.id}: $e');
          continue;
        }
      }

      print('📊 Session processing summary:');
      print('   - Total documents: ${querySnapshot.docs.length}');
      print('   - Valid sessions: $validCount');
      print('   - Invalid sessions: $invalidCount');

      // ✅ IMPORTANT: Sync profile stats with actual session count
      await _syncProfileStats(sessions);

      // Sort by date (newest first)
      sessions.sort((a, b) => b.date.compareTo(a.date));
      
      print('✅ Successfully loaded ${sessions.length} valid sessions');
      return sessions;

    } catch (e) {
      print('❌ Error fetching training sessions: $e');
      return [];
    }
  }

  /// ✅ NEW: Sync profile stats with actual session data
  static Future<void> _syncProfileStats(List<TrainingSession> sessions) async {
    try {
      print('🔄 Syncing profile stats with actual session data...');
      
      final profile = await ProfileService.getUserProfile();
      if (profile == null) return;

      // Calculate actual totals from sessions
      final actualSessionCount = sessions.length;
      final actualTotalDistance = sessions.fold<double>(0.0, (sum, session) => sum + (session.trainingDistance / 1000));
      final actualTotalHours = sessions.fold<int>(0, (sum, session) => sum + (session.sessionDuration / 60).round());

      // Check if sync is needed
      if (profile.totalSessions != actualSessionCount ||
          (profile.totalDistance - actualTotalDistance).abs() > 0.1 ||
          profile.totalHours != actualTotalHours) {
        
        print('⚠️ Profile stats mismatch detected:');
        print('   - Profile: ${profile.totalSessions} sessions, ${profile.totalDistance}km, ${profile.totalHours}h');
        print('   - Actual: $actualSessionCount sessions, ${actualTotalDistance.toStringAsFixed(2)}km, ${actualTotalHours}h');
        
        // Update profile with correct stats
        final updatedProfile = profile.copyWith(
          totalSessions: actualSessionCount,
          totalDistance: actualTotalDistance,
          totalHours: actualTotalHours,
          updatedAt: DateTime.now(),
        );
        
        await ProfileService.saveUserProfile(updatedProfile);
        print('✅ Profile stats synchronized successfully');
      } else {
        print('✅ Profile stats are already in sync');
      }
    } catch (e) {
      print('❌ Error syncing profile stats: $e');
    }
  }

  /// ✅ NEW: Better validation error logging
  static void _logValidationErrors(Map<String, dynamic> data) {
    print('   Validation errors:');
    if (data['trainingDistance'] == null) print('     - Missing trainingDistance');
    if (data['actualTime'] == null) print('     - Missing actualTime');
    if (data['strokeType'] == null) print('     - Missing strokeType');
    if (data['date'] == null) print('     - Missing date');
    
    if (data['trainingDistance'] != null) {
      try {
        final distance = (data['trainingDistance'] as num).toDouble();
        if (distance <= 0) print('     - Invalid distance: $distance');
      } catch (e) {
        print('     - Invalid distance type: ${data['trainingDistance']?.runtimeType}');
      }
    }
    
    if (data['actualTime'] != null) {
      try {
        final time = (data['actualTime'] as num).toDouble();
        if (time <= 0) print('     - Invalid time: $time');
      } catch (e) {
        print('     - Invalid time type: ${data['actualTime']?.runtimeType}');
      }
    }
  }

  /// ✅ FIXED: Better validation that handles Timestamps
  static bool _isValidSessionData(Map<String, dynamic> data) {
    try {
      // Check for essential fields
      if (data['trainingDistance'] == null ||
          data['actualTime'] == null ||
          data['strokeType'] == null ||
          data['date'] == null) {
        return false;
      }

      // Validate numeric fields
      final distance = (data['trainingDistance'] as num).toDouble();
      final time = (data['actualTime'] as num).toDouble();
      
      if (distance <= 0 || time <= 0) {
        return false;
      }

      // Validate date field (can be Timestamp or String)
      if (data['date'] is! Timestamp && data['date'] is! String) {
        return false;
      }

      // If date is string, try to parse it
      if (data['date'] is String) {
        DateTime.parse(data['date'] as String);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// ✅ IMPLEMENTED: Complete delete functionality
  static Future<void> deleteTrainingSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      print('🗑️ Deleting training session: $sessionId');

      // Get the session data before deleting for profile update
      final sessionDoc = await _firestore
          .collection(_trainingSessions)
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final distance = (sessionData['trainingDistance'] as num?)?.toDouble() ?? 0.0;
      final duration = (sessionData['sessionDuration'] as num?)?.toDouble() ?? 0.0;

      // Delete the session
      await _firestore
          .collection(_trainingSessions)
          .doc(sessionId)
          .delete();

      print('✅ Session deleted successfully');

      // ✅ Update profile stats
      await _updateProfileAfterDelete(distance, duration);

    } catch (e) {
      print('❌ Error deleting training session: $e');
      throw e;
    }
  }

  /// ✅ NEW: Update profile stats after deleting a session
  static Future<void> _updateProfileAfterDelete(double distance, double duration) async {
    try {
      final profile = await ProfileService.getUserProfile();
      if (profile == null) return;

      final newSessionCount = profile.totalSessions - 1;
      final newTotalDistance = profile.totalDistance - (distance / 1000);
      final newTotalHours = profile.totalHours - (duration / 60).round();

      final updatedProfile = profile.copyWith(
        totalSessions: newSessionCount > 0 ? newSessionCount : 0,
        totalDistance: newTotalDistance > 0 ? newTotalDistance : 0.0,
        totalHours: newTotalHours > 0 ? newTotalHours : 0,
        updatedAt: DateTime.now(),
      );

      await ProfileService.saveUserProfile(updatedProfile);
      print('✅ Profile updated after session deletion');
    } catch (e) {
      print('❌ Error updating profile after delete: $e');
    }
  }

  /// ✅ IMPROVED: Better alternative queries with Timestamp handling
  static Future<List<TrainingSession>> _tryAlternativeQueries() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      print('🔄 Trying alternative query methods...');

      // Try with 'uid' field instead of 'userId'
      var querySnapshot = await _firestore
          .collection(_trainingSessions)
          .where('uid', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found ${querySnapshot.docs.length} sessions using uid field');
        final sessions = <TrainingSession>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            if (_isValidSessionData(data)) {
              sessions.add(TrainingSession.fromFirestore(data, doc.id));
            }
          } catch (e) {
            print('❌ Error parsing alternative session ${doc.id}: $e');
            continue;
          }
        }
        
        return sessions;
      }

      // Try different collection name
      querySnapshot = await _firestore
          .collection('trainingSessions')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        print('✅ Found ${querySnapshot.docs.length} sessions in trainingSessions collection');
        final sessions = <TrainingSession>[];
        
        for (final doc in querySnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            if (_isValidSessionData(data)) {
              sessions.add(TrainingSession.fromFirestore(data, doc.id));
            }
          } catch (e) {
            print('❌ Error parsing collection session ${doc.id}: $e');
            continue;
          }
        }
        
        return sessions;
      }

      print('ℹ️ No training sessions found with alternative queries');
      return [];

    } catch (e) {
      print('❌ Error in alternative queries: $e');
      return [];
    }
  }

  /// ✅ Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      print('🔍 Getting user profile via ProfileService...');
      final profile = await ProfileService.getUserProfile();
      
      if (profile != null) {
        print('✅ Profile found: ${profile.name}, sessions: ${profile.totalSessions}');
        return {
          'gender': profile.gender ?? 'Male',
          'name': profile.name ?? 'Swimmer',
          'age': profile.age,
          'weight': profile.weight,
          'favoriteStyle': profile.favoriteStyle,
          'totalSessions': profile.totalSessions,
          'totalDistance': profile.totalDistance,
          'totalHours': profile.totalHours,
        };
      } else {
        print('❌ No profile found');
        return {
          'gender': 'Male',
          'name': 'Swimmer',
          'totalSessions': 0,
          'totalDistance': 0.0,
          'totalHours': 0,
        };
      }
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return {
        'gender': 'Male',
        'name': 'Swimmer',
        'totalSessions': 0,
        'totalDistance': 0.0,
        'totalHours': 0,
      };
    }
  }

  /// ✅ NEW: Force refresh profile stats
  static Future<void> refreshProfileStats() async {
    try {
      final sessions = await getUserTrainingSessions();
      print('✅ Profile stats refreshed');
    } catch (e) {
      print('❌ Error refreshing profile stats: $e');
    }
  }
}