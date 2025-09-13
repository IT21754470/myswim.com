import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestFirebase extends StatefulWidget {
  const TestFirebase({super.key});

  @override
  State<TestFirebase> createState() => _TestFirebaseState();
}

class _TestFirebaseState extends State<TestFirebase> {
  String _message = "Testing Firebase connection...";

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      print("Firebase Auth initialized: ${auth.app.name}");
      
      // Test Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.enableNetwork();
      print("Firestore connected successfully");
      
      setState(() {
        _message = "✅ Firebase is connected successfully!\n"
                  "Auth: ${auth.app.name}\n"
                  "Current user: ${auth.currentUser?.email ?? 'None'}";
      });
    } catch (e) {
      setState(() {
        _message = "❌ Firebase connection failed:\n$e";
      });
      print("Firebase test error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
        backgroundColor: const Color.fromARGB(255, 19, 85, 143),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}