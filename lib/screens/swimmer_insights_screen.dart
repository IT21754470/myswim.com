import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swimming_app/models/user_profile.dart';
import 'package:swimming_app/screens/fatigue_prediction_screen.dart';
import 'improvement_prediction_screen.dart';
import 'add_training_session_screen.dart';
import '../services/profile_service.dart';
import "recommendations_screen.dart"; // ✅ Add this import

class SwimmingInsightsScreen extends StatefulWidget {
  const SwimmingInsightsScreen({super.key});

  @override
  State<SwimmingInsightsScreen> createState() => _SwimmingInsightsScreenState();
}

class _SwimmingInsightsScreenState extends State<SwimmingInsightsScreen> {
  int sessionCount = 0;
  double totalDistance = 0.0;
  int totalHours = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  // ✅ New method to load all user stats from ProfileService
  Future<void> _loadUserStats() async {
    if (!mounted) return;
    
    setState(() {
      isLoadingStats = true;
    });

    try {
      print('📊 Loading user stats from ProfileService...');
      
      final userProfile = await ProfileService.getUserProfile();
      
      if (mounted && userProfile != null) {
        setState(() {
          sessionCount = userProfile.totalSessions;
          totalDistance = userProfile.totalDistance;
          totalHours = userProfile.totalHours;
          isLoadingStats = false;
        });
        
        print('✅ Stats loaded: $sessionCount sessions, ${totalDistance}km, ${totalHours}h');
      } else {
        // If no profile exists, create a default one
        print('ℹ️ No profile found, creating default...');
        final user = FirebaseAuth.instance.currentUser;
        final defaultProfile = UserProfile(
          name: user?.displayName ?? user?.email?.split('@')[0] ?? 'Swimmer',
          gender: 'Male',
          totalSessions: 0,
          totalDistance: 0.0,
          totalHours: 0,
          createdAt: DateTime.now(),
        );
        
        await ProfileService.saveUserProfile(defaultProfile);
        
        if (mounted) {
          setState(() {
            sessionCount = 0;
            totalDistance = 0.0;
            totalHours = 0;
            isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user stats: $e');
      if (mounted) {
        setState(() {
          sessionCount = 0;
          totalDistance = 0.0;
          totalHours = 0;
          isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Swimming Insights'),
        backgroundColor: const Color(0xFF2A5298),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadUserStats, // ✅ Refresh stats
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section - Updated with real stats
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3C72),
                    Color(0xFF2A5298),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'AI-Powered Analysis',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get personalized insights and predictions to optimize your performance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // ✅ Updated Quick Stats with real data
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat(
                          'Sessions',
                          isLoadingStats ? '...' : sessionCount.toString(),
                          Icons.pool,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStat(
                          'Distance',
                          isLoadingStats ? '...' : '${totalDistance.toStringAsFixed(1)}km',
                          Icons.straighten,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStat(
                          'Hours',
                          isLoadingStats ? '...' : '${totalHours}h',
                          Icons.timer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Analysis Cards
            const Text(
              'Choose Analysis Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3C72),
              ),
            ),
            const SizedBox(height: 16),

            // Insight Cards
            _buildInsightCard(
              title: 'Improvement Prediction',
              description: 'AI predictions for performance optimization',
              icon: Icons.trending_up,
              sessionCount: sessionCount, // ✅ Pass session count
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImprovementPredictionScreen(),
                  ),
                );
                // ✅ Refresh stats when returning from any screen
                if (result == true) {
                  _loadUserStats();
                }
              },
            ),

            const SizedBox(height: 16),

         // In your _buildInsightCard calls, update the fatigue prediction:

_buildInsightCard(
  title: 'Fatigue Prediction',
  description: 'Monitor your training load and recovery needs',
  icon: Icons.battery_alert,
  sessionCount: sessionCount,
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFfa709a), Color.fromARGB(255, 187, 177, 120)],
  ),
  onTap: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FatiguePredictionScreen(),
      ),
    );
    if (result == true) {
      _loadUserStats();
    }
  },
),
 const SizedBox(height: 16),
 
            _buildInsightCard(
              title: 'Insights & Recommendations',
              description: 'Personalized training tips and suggestions',
              icon: Icons.lightbulb,
              sessionCount: sessionCount, // ✅ Pass session count
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            onTap: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecommendationsScreen(),
      ),
    );
    if (result == true) {
      _loadUserStats();
    }
  },
),
 const SizedBox(height: 16),

            // ✅ Updated Recent Activity Section with real data
            _buildRecentActivitySection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTrainingSessionScreen(),
            ),
          );
          // ✅ Refresh stats when new session is added
          if (result == true) {
            _loadUserStats();
          }
        },
        backgroundColor: const Color(0xFF2A5298),
        icon: const Icon(Icons.pool, color: Colors.white),
        label: const Text('Add Training Data', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildQuickStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Updated insight card to show session requirement
  Widget _buildInsightCard({
    required String title,
    required String description,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    required int sessionCount,
  }) {
    final bool hasEnoughSessions = sessionCount > 0;
    
    return GestureDetector(
      onTap: hasEnoughSessions ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: hasEnoughSessions ? gradient : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(hasEnoughSessions ? 0.1 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(hasEnoughSessions ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasEnoughSessions ? Colors.white : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: hasEnoughSessions ? Colors.white : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasEnoughSessions 
                        ? description 
                        : 'Add training sessions to unlock this feature',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasEnoughSessions 
                          ? Colors.white.withOpacity(0.9) 
                          : Colors.grey.withOpacity(0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (hasEnoughSessions) Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ) else Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$sessionCount sessions',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Updated Recent Activity Section with real data
  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Swimming Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2A5298),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Sessions', 
                isLoadingStats ? '...' : sessionCount.toString(), 
                Icons.pool
              ),
              _buildStatItem(
                'Distance', 
                isLoadingStats ? '...' : '${totalDistance.toStringAsFixed(1)}km', 
                Icons.straighten
              ),
              _buildStatItem(
                'Training Time', 
                isLoadingStats ? '...' : '${totalHours}h', 
                Icons.timer
              ),
            ],
          ),
          if (sessionCount == 0) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.pool_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start your swimming journey!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first training session to track progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2A5298), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2A5298),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ... rest of your existing methods for notifications, etc.
}