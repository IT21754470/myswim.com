// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseStatusScreen extends StatefulWidget {
  const FirebaseStatusScreen({super.key});

  @override
  State<FirebaseStatusScreen> createState() => _FirebaseStatusScreenState();
}

class _FirebaseStatusScreenState extends State<FirebaseStatusScreen> {
  String _firebaseStatus = "Checking Firebase connection...";
  String _authStatus = "Checking Auth...";
  String _firestoreStatus = "Checking Firestore...";
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkFirebaseConnection();
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      // Check Firebase Core
      final app = Firebase.app();
      setState(() {
        _firebaseStatus = "✅ Firebase Core: Connected (${app.name})";
      });

      // Check Firebase Auth
      final auth = FirebaseAuth.instance;
      setState(() {
        _authStatus = "✅ Firebase Auth: Ready";
      });

      // Check Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.enableNetwork();
      
      // Test Firestore connection
      await firestore.collection('test').limit(1).get();
      
      setState(() {
        _firestoreStatus = "✅ Cloud Firestore: Connected & Ready";
        _isConnected = true;
      });

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Firebase connected successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _firebaseStatus = "❌ Firebase connection failed";
        _authStatus = "❌ Auth connection failed";
        _firestoreStatus = "❌ Firestore connection failed: $e";
        _isConnected = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Firebase connection failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 4, 30, 66),
      appBar: AppBar(
        title: const Text('Firebase Status'),
        backgroundColor: const Color.fromARGB(255, 19, 85, 143),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Firebase Logo
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  size: 50,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Status Cards
            _buildStatusCard(
              icon: Icons.flash_on,
              title: "Firebase Core",
              status: _firebaseStatus,
              isConnected: _firebaseStatus.contains("✅"),
            ),
            const SizedBox(height: 16),

            _buildStatusCard(
              icon: Icons.person,
              title: "Firebase Auth",
              status: _authStatus,
              isConnected: _authStatus.contains("✅"),
            ),
            const SizedBox(height: 16),

            _buildStatusCard(
              icon: Icons.storage,
              title: "Cloud Firestore",
              status: _firestoreStatus,
              isConnected: _firestoreStatus.contains("✅"),
            ),
            const SizedBox(height: 32),

            // Current User Info
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                return _buildStatusCard(
                  icon: Icons.account_circle,
                  title: "Current User",
                  status: snapshot.hasData 
                      ? "✅ Logged in: ${snapshot.data!.email}" 
                      : "ℹ️ No user logged in",
                  isConnected: snapshot.hasData,
                );
              },
            ),
            const SizedBox(height: 32),

            // Retry Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _checkFirebaseConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('Recheck Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String status,
    required bool isConnected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isConnected ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.red,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}