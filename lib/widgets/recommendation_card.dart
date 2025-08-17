import 'package:flutter/material.dart';
import 'package:swimming_app/services/recommendations_service.dart';
import '../screens/recommendations_screen.dart';

class RecommendationCard extends StatelessWidget {
  final int? totalRecommendations;
  final String? fatigueLevel;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const RecommendationCard({
    super.key,
    this.totalRecommendations,
    this.fatigueLevel,
    this.isLoading = false,
    this.onRefresh,
  });

  // Rest of your existing code...

  // Rest of the widget remains the same...

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RecommendationsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Training Recommendations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  isLoading 
                      ? 'Analyzing your training data...'
                      : 'Get personalized training advice based on your performance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Stats row
                if (!isLoading) ...[
                  Row(
                    children: [
                      if (totalRecommendations != null) ...[
                        _buildStat(
                          totalRecommendations.toString(),
                          'Available',
                          Icons.star,
                        ),
                        const SizedBox(width: 24),
                      ],
                      if (fatigueLevel != null)
                        _buildStat(
                          fatigueLevel!,
                          'Fatigue Level',
                          _getFatigueIcon(fatigueLevel!),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'View All',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Loading placeholder
                  Row(
                    children: [
                      _buildLoadingPlaceholder(60, 12),
                      const SizedBox(width: 24),
                      _buildLoadingPlaceholder(80, 12),
                      const Spacer(),
                      _buildLoadingPlaceholder(70, 32),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  IconData _getFatigueIcon(String fatigueLevel) {
    switch (fatigueLevel.toUpperCase()) {
      case 'HIGH':
        return Icons.battery_1_bar;
      case 'MEDIUM':
        return Icons.battery_3_bar;
      case 'LOW':
        return Icons.battery_full;
      default:
        return Icons.battery_unknown;
    }
  }
}