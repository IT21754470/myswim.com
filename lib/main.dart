import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:swimming_app/screens/settings_screen.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/main_layout.dart';
import 'screens/improvement_prediction_screen.dart';
import 'screens/add_training_session_screen.dart';
import 'screens/swimmer_insights_screen.dart';
import 'screens/competitions_screen.dart';
import 'screens/injury_prediction_screen.dart';
import 'screens/turn_start_analysis_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/TrainingSessionsScreen.dart';
//import 'screens/fatigue_dashboard_screen.dart';
//import 'screens/add_training_session_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Success messages
    print("🔥 Firebase initialized successfully!");
    print("✅ Firebase Core: Connected");
    print("✅ Firebase Auth: Ready");
    print("✅ Cloud Firestore: Ready");
    
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwimSight',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    routes: {
  '/splash': (context) => const SplashScreen(),
  '/auth': (context) => const AuthWrapper(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/forgot-password': (context) => const ForgotPasswordScreen(),
  '/main': (context) => const MainLayout(),
  '/improvement-prediction': (context) => const ImprovementPredictionScreen(),
  '/add-training': (context) => const AddTrainingSessionScreen(),
  '/competitions': (context) => const CompetitionsScreen(),
  '/injury-risk': (context) => const InjuryPredictionScreen(),
  '/turn-start-analysis': (context) => const TurnStartAnalysisScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/settings': (context) => const SettingsScreen(),
  '/training-sessions': (context) => const TrainingSessionsScreen(),
},
    );
  }
}

