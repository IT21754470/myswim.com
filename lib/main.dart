import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swimming_app/screens/settings_screen.dart';

import 'firebase_options.dart';
import 'models/swim_history_store.dart';

// Screens
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
import 'screens/settings_screen.dart';

// New screens
import 'screens/swimmer_performance_screen.dart';
import 'screens/predict_best_finishing_time_screen.dart';
import 'screens/swimmer_dashboard_screen.dart';
import 'screens/analysis_results_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Optional: anonymous auth for local/dev
    // Remove for production if you require explicit login.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('✅ Signed in anonymously (dev)');
    }
  } catch (e, st) {
    debugPrint('❌ Firebase initialization failed: $e');
    if (kDebugMode) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'main.dart',
        informationCollector: () sync* {
          yield ErrorDescription('Firebase failed to initialize.');
        },
      ));
    }
  }

  // Load local history after Firebase init
  try {
    // If you add remote sync later, configure BEFORE load():
    // SwimHistoryStore().configureRemote(baseUrl: 'https://timeprediction-backend.onrender.com');
    await SwimHistoryStore().load();
    debugPrint('✅ SwimHistoryStore loaded.');
  } catch (e) {
    debugPrint('❌ SwimHistoryStore load failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwimSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Boot with Splash (it can decide where to go next)
      home: const SplashScreen(),

      routes: {
        '/splash': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/main': (context) => const MainLayout(),
        '/improvement-prediction': (context) => const ImprovementPredictionScreen(),
        '/add-training': (context) => const AddTrainingSessionScreen(),
        '/competitions': (context) => const CompetitionScreen(),
        '/injury-risk': (context) => const InjuryPredictionScreen(),
        '/turn-start-analysis': (context) => const TurnStartAnalysisScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),

        // New
        '/swimmer-performance': (context) => const SwimmerPerformanceScreen(),
        '/predict-best-finishing-time': (context) => const PredictBestFinishingTimeScreen(),
        '/swimmer-dashboard': (context) => const SwimmerDashboardScreen(),
        '/analysis-results': (context) => const AnalysisResultsScreen(),
      },

      // Fallback route (keeps the app navigable if a name is wrong)
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const SwimmerPerformanceScreen(),
      ),
    );
  }
}
