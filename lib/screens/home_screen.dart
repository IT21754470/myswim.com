// ignore_for_file: avoid_print, deprecated_member_use, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'swimmer_insights_screen.dart';
import 'competitions_screen.dart';
import 'turn_start_analysis_screen.dart';
import 'injury_prediction_screen.dart';
import 'add_training_session_screen.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int sessionCount = 0;
  double totalDistance = 0.0;
  int totalHours = 0;
  bool isLoadingStats = true;
  UserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    
    setState(() {
      isLoadingStats = true;
    });

    try {
      print('📊 Loading stats for HomeScreen...');
      
      final profile = await ProfileService.getUserProfile();
      
      if (mounted) {
        if (profile != null) {
          setState(() {
            userProfile = profile;
            sessionCount = profile.totalSessions;
            totalDistance = profile.totalDistance;
            totalHours = profile.totalHours;
            isLoadingStats = false;
          });
          
          print('✅ HomeScreen stats loaded: $sessionCount sessions, ${totalDistance}km');
        } else {
          // Create default profile if none exists
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
          
          setState(() {
            userProfile = defaultProfile;
            sessionCount = 0;
            totalDistance = 0.0;
            totalHours = 0;
            isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading HomeScreen stats: $e');
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

  Future<void> _refreshStats() async {
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.dashboard,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, ${userProfile?.name ?? user?.displayName ?? 'Swimmer'}!',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track, analyze, and improve your performance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshStats,
                          icon: Icon(
                            Icons.refresh,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Stats
              _buildQuickStats(),
              const SizedBox(height: 24),
              
              // Main Feature Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Performance Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3C72),
                    ),
                  ),
                  if (sessionCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF4CAF50),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: const Color(0xFF4CAF50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Feature Cards Grid
             GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  childAspectRatio: 0.85, // ✅ Changed from 1.0 to 0.85 to give more height
  children: [
                  _buildFeatureCard(
                    title: 'Swimmer Insights',
                    description: 'AI-powered performance analysis',
                    icon: Icons.analytics,
                    sessionCount: sessionCount,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SwimmingInsightsScreen(),
                        ),
                      );
                      if (result == true) {
                        _refreshStats();
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Competitions',
                    description: 'Track your competition results',
                    icon: Icons.emoji_events,
                    sessionCount: sessionCount,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompetitionScreen(),
                        ),
                      );
                      if (result == true) {
                        _refreshStats();
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Turn & Start Analysis',
                    description: 'Optimize your technique',
                    icon: Icons.compare_arrows,
                    sessionCount: sessionCount,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TurnStartAnalysisScreen(),
                        ),
                      );
                      if (result == true) {
                        _refreshStats();
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: 'Injury Risk Prediction',
                    description: 'Stay safe and healthy',
                    icon: Icons.health_and_safety,
                    sessionCount: sessionCount,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFfa709a), Color(0xFFfee140)],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InjuryPredictionScreen(),
                        ),
                      );
                      if (result == true) {
                        _refreshStats();
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions Section
              if (sessionCount == 0) ...[
                _buildGetStartedSection(),
              ] else ...[
                _buildQuickActionsSection(),
              ],

              const SizedBox(height: 24),

              // Recent Activity or Motivational Section
              _buildBottomSection(),
            ],
          ),
        ),
      ),
      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTrainingSessionScreen(),
            ),
          );
          if (result == true) {
            _refreshStats();
          }
        },
        backgroundColor: const Color(0xFF2A5298),
        icon: const Icon(Icons.pool, color: Colors.white),
        label: Text(
          sessionCount == 0 ? 'Start Swimming' : 'Add Session',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Sessions',
            isLoadingStats ? '...' : sessionCount.toString(),
            Icons.pool,
            const Color(0xFF2A5298),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Distance',
            isLoadingStats ? '...' : '${totalDistance.toStringAsFixed(1)}km',
            Icons.straighten,
            const Color(0xFF764ba2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Hours',
            isLoadingStats ? '...' : '${totalHours}h',
            Icons.timer,
            const Color(0xFF667eea),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildFeatureCard({
  required String title,
  required String description,
  required IconData icon,
  required Gradient gradient,
  required VoidCallback onTap,
  required int sessionCount,
}) {
  final bool isEnabled = sessionCount > 0 || title == 'Swimmer Insights';
  final bool showRequirement = !isEnabled && title != 'Swimmer Insights';

  return GestureDetector(
    onTap: isEnabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.all(16), // ✅ Reduced from 20 to 16
      decoration: BoxDecoration(
        gradient: isEnabled ? gradient : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.withOpacity(0.3),
            Colors.grey.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isEnabled ? 0.1 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon and requirement badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // ✅ Reduced from 12 to 10
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isEnabled ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10), // ✅ Reduced from 12 to 10
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? Colors.white : Colors.grey,
                  size: 22, // ✅ Reduced from 24 to 22
                ),
              ),
              if (showRequirement)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Need data',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8), // ✅ Reduced spacing
          
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14, // ✅ Reduced from 16 to 14
              fontWeight: FontWeight.bold,
              color: isEnabled ? Colors.white : Colors.grey[600],
            ),
            maxLines: 2, // ✅ Add maxLines
            overflow: TextOverflow.ellipsis, // ✅ Add overflow handling
          ),
          
          const SizedBox(height: 4), // ✅ Reduced spacing
          
          // Description
          Expanded( // ✅ Wrap in Expanded to take remaining space
            child: Text(
              showRequirement ? 'Add training sessions first' : description,
              style: TextStyle(
                fontSize: 11, // ✅ Reduced from 12 to 11
                color: isEnabled 
                    ? Colors.white.withOpacity(0.9) 
                    : Colors.grey[500],
                height: 1.2, // ✅ Reduce line height
              ),
              maxLines: 3, // ✅ Limit to 3 lines
              overflow: TextOverflow.ellipsis, // ✅ Handle overflow
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildGetStartedSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2A5298).withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.rocket_launch,
            size: 48,
            color: const Color(0xFF2A5298),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready to Start Your Journey?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3C72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first training session to unlock AI-powered insights and performance tracking.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTrainingSessionScreen(),
                      ),
                    );
                    if (result == true) {
                      _refreshStats();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A5298),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3C72),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'New Session',
                Icons.add_circle_outline,
                const Color(0xFF4CAF50),
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddTrainingSessionScreen(),
                    ),
                  );
                  if (result == true) {
                    _refreshStats();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'View All',
                Icons.list_alt,
                const Color(0xFF2196F3),
                () {
                  // Navigate to training sessions list
                  Navigator.pushNamed(context, '/training-sessions');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    if (sessionCount == 0) {
      return _buildMotivationalSection();
    } else {
      return _buildRecentActivitySection();
    }
  }

  Widget _buildMotivationalSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3E5F5),
            Color(0xFFE8EAF6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '💪 Swimming Tips',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3C72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '"The water is your friend. You don\'t have to fight with water, just share the same spirit as the water, and it will help you move."',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '- Aleksandr Popov',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2A5298),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/training-sessions');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProgressItem(
                  'Total Sessions',
                  sessionCount.toString(),
                  Icons.pool,
                  const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: _buildProgressItem(
                  'Distance',
                  '${totalDistance.toStringAsFixed(1)}km',
                  Icons.straighten,
                  const Color(0xFF2196F3),
                ),
              ),
              Expanded(
                child: _buildProgressItem(
                  'Time',
                  '${totalHours}h',
                  Icons.timer,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


