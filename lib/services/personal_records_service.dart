import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/personal_record.dart';
import '../models/training_session.dart';

class PersonalRecordsService {
  static final _firestore = FirebaseFirestore.instance;
  
  /// Check if the session is a new personal record
  static Future<List<PersonalRecord>> checkForNewRecords(TrainingSession session) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in for PR check');
      return [];
    }
    
    print('🔍 Checking for PR: ${session.strokeType} ${session.trainingDistance}m');
    print('🔍 Pace: ${session.pacePer100m}s/100m, Time: ${session.actualTime}s');
    
    final newRecords = <PersonalRecord>[];
    
    try {
      // Query existing records for this stroke and distance combination
      final existingQuery = await _firestore
          .collection('personal_records')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: session.strokeType)
          .where('distance', isEqualTo: session.trainingDistance)
          .where('isCurrentRecord', isEqualTo: true)
          .limit(1)
          .get();
      
      bool isNewRecord = false;
      
      if (existingQuery.docs.isEmpty) {
        // First time swimming this distance/stroke combo
        print('🆕 First time swimming ${session.strokeType} ${session.trainingDistance}m!');
        isNewRecord = true;
      } else {
        // Compare with existing record
        final existingRecord = existingQuery.docs.first.data();
        final existingPace = (existingRecord['pace'] ?? 0).toDouble();
        
        print('📊 Comparing - Existing pace: ${existingPace.toStringAsFixed(2)}s/100m, New pace: ${session.pacePer100m.toStringAsFixed(2)}s/100m');
        
        if (session.pacePer100m < existingPace) {
          print('🏆 NEW PR! Previous: ${existingPace.toStringAsFixed(2)}s/100m, New: ${session.pacePer100m.toStringAsFixed(2)}s/100m');
          isNewRecord = true;
          
          // Mark old record as not current
          await _firestore
              .collection('personal_records')
              .doc(existingQuery.docs.first.id)
              .update({'isCurrentRecord': false});
          
          print('✅ Old record marked as inactive');
        } else {
          print('📊 Not a PR. Current best: ${existingPace.toStringAsFixed(2)}s/100m');
        }
      }
      
      if (isNewRecord) {
        // Create new PR record
        final prData = {
          'userId': user.uid,
          'strokeType': session.strokeType,
          'distance': session.trainingDistance,
          'time': session.actualTime,
          'pace': session.pacePer100m,
          'achievedDate': Timestamp.fromDate(session.date),
          'poolLength': session.poolLength.toString(),
          'isCurrentRecord': true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        print('💾 Saving new PR: $prData');
        
        final docRef = await _firestore
            .collection('personal_records')
            .add(prData);
        
        final pr = PersonalRecord.fromJson({
          ...prData,
          'id': docRef.id,
          'achievedDate': session.date.toIso8601String(),
        });
        
        newRecords.add(pr);
        
        print('✅ PR saved with ID: ${docRef.id}');
      }
      
      return newRecords;
    } catch (e, stackTrace) {
      print('❌ Error checking for PR: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Get all personal records for the current user
  static Future<List<PersonalRecord>> getUserRecords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return [];
    }
    
    try {
      print('📊 Loading personal records for user: ${user.uid}');
      
      // Get all records for this user
      final snapshot = await _firestore
          .collection('personal_records')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      print('📊 Found ${snapshot.docs.length} total documents');
      
      if (snapshot.docs.isEmpty) {
        print('⚠️ No records found in database');
        return [];
      }
      
      // Filter for current records and convert to objects
      final records = <PersonalRecord>[];
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          print('Processing document ${doc.id}: $data');
          
          final record = PersonalRecord.fromJson({
            ...data,
            'id': doc.id,
          });
          
          // Only include current records
          if (record.isCurrentRecord) {
            records.add(record);
            print('✅ Added record: ${record.strokeType} ${record.distance}m');
          }
        } catch (e) {
          print('⚠️ Error processing document ${doc.id}: $e');
        }
      }
      
      // Sort by date descending
      records.sort((a, b) => b.achievedDate.compareTo(a.achievedDate));
      
      print('✅ Loaded ${records.length} current personal records');
      return records;
    } catch (e, stackTrace) {
      print('❌ Error loading records: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Get personal records grouped by stroke type
  static Future<Map<String, List<PersonalRecord>>> getRecordsByStroke() async {
    final records = await getUserRecords();
    final grouped = <String, List<PersonalRecord>>{};
    
    print('📊 Grouping ${records.length} records by stroke');
    
    for (final record in records) {
      grouped.putIfAbsent(record.strokeType, () => []).add(record);
    }
    
    // Sort records within each stroke by distance
    grouped.forEach((stroke, recordList) {
      recordList.sort((a, b) => a.distance.compareTo(b.distance));
    });
    
    print('📊 Grouped records: ${grouped.keys.join(', ')}');
    for (var entry in grouped.entries) {
      print('  ${entry.key}: ${entry.value.length} records');
    }
    
    return grouped;
  }
  
  /// Get the best pace for a specific stroke
  static Future<PersonalRecord?> getBestPaceForStroke(String strokeType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    try {
      final snapshot = await _firestore
          .collection('personal_records')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .where('isCurrentRecord', isEqualTo: true)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      // Find best pace in memory
      final records = snapshot.docs
          .map((doc) => PersonalRecord.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      records.sort((a, b) => a.pace.compareTo(b.pace));
      
      return records.first;
    } catch (e) {
      print('❌ Error getting best pace: $e');
      return null;
    }
  }
  
  /// Get total count of personal records
  static Future<int> getTotalRecordsCount() async {
    try {
      final records = await getUserRecords();
      print('📊 Total records count: ${records.length}');
      return records.length;
    } catch (e) {
      print('❌ Error getting record count: $e');
      return 0;
    }
  }
  
  /// Delete a personal record
  static Future<bool> deleteRecord(String recordId) async {
    try {
      await _firestore.collection('personal_records').doc(recordId).delete();
      print('✅ Record deleted: $recordId');
      return true;
    } catch (e) {
      print('❌ Error deleting record: $e');
      return false;
    }
  }
  
  /// Get records history (including old records)
  static Future<List<PersonalRecord>> getRecordHistory(String strokeType, double distance) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    try {
      final snapshot = await _firestore
          .collection('personal_records')
          .where('userId', isEqualTo: user.uid)
          .where('strokeType', isEqualTo: strokeType)
          .where('distance', isEqualTo: distance)
          .get();
      
      // Sort in memory
      final records = snapshot.docs
          .map((doc) => PersonalRecord.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      records.sort((a, b) => b.achievedDate.compareTo(a.achievedDate));
      
      return records;
    } catch (e) {
      print('❌ Error loading history: $e');
      return [];
    }
  }
}