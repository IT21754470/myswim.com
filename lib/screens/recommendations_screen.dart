import 'package:flutter/material.dart';
import '../services/recommendations_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationsService _service = RecommendationsService();
  List<SwimmingRecommendation> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recommendations = await _service.getUserRecommendations();
      
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(
      title: const Text('Recommendations'),
      backgroundColor: const Color(0xFF4A90E2),
      foregroundColor: Colors.white,
      actions: [
        // ✅ Show API status
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _service.isOfflineMode 
                    ? Colors.orange.withOpacity(0.2) 
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _service.isOfflineMode ? Icons.offline_bolt : Icons.cloud_done,
                    size: 16,
                    color: _service.isOfflineMode ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _service.isOfflineMode ? 'Local' : 'AI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _service.isOfflineMode ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: _loadRecommendations,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _buildBody(),
  );
}
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
   
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading recommendations...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const Center(
        child: Text('No recommendations available'),
      );
    }

    return Column(
      children: [
        // Summary
      Container(
  margin: const EdgeInsets.all(16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [const Color(0xFF4A90E2), const Color(0xFF357ABD)],
    ),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _buildSummaryItem(
        'Total', 
        '${_recommendations.length}', 
        Icons.star
      ),
      _buildSummaryItem(
        'Mode', 
        _service.isOfflineMode ? 'Local' : 'AI+Local',
        _service.isOfflineMode ? Icons.offline_bolt : Icons.psychology,
      ),
      _buildSummaryItem(
        'Quality', 
        _recommendations.isEmpty ? 'N/A' : 
            '${(_recommendations.map((r) => r.confidence).reduce((a, b) => a + b) / _recommendations.length).round()}%',
        Icons.verified,
      ),
    ],
  ),
),
        
        // Recommendations List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              return _buildRecommendationCard(_recommendations[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

 // In your RecommendationsScreen, update this part:
Widget _buildRecommendationCard(SwimmingRecommendation recommendation) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getTypeColor(recommendation.type),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(_getTypeIcon(recommendation.type), color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      recommendation.type,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${recommendation.confidence}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommendation.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),

              // Details - Fixed overflow
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDetailChip('Priority', recommendation.priority, 
                        _getPriorityColor(recommendation.priority)),
                    const SizedBox(width: 8),
                    _buildDetailChip('Duration', recommendation.duration, Colors.blue),
                    const SizedBox(width: 8),
                    _buildDetailChip('Difficulty', recommendation.difficulty, Colors.orange),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              const Text(
                'Instructions:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...recommendation.instructions.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90E2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 12),

              // Fatigue level
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getFatigueColor(recommendation.fatigueLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.battery_std,
                      color: _getFatigueColor(recommendation.fatigueLevel),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current fatigue level: ${recommendation.fatigueLevel}',
                        style: TextStyle(
                          color: _getFatigueColor(recommendation.fatigueLevel),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildDetailChip(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

 Color _getTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'ai-powered':
      return const Color(0xFF6C5CE7); // Purple for AI
    case 'data-driven':
      return const Color(0xFF00B894); // Green for data-driven
    case 'skill-building':
      return const Color(0xFF0984E3); // Blue for skill building
    case 'consistency':
      return const Color(0xFFE17055); // Orange for consistency
    case 'motivation':
      return const Color(0xFFE84393); // Pink for motivation
    case 'stroke':
      return const Color(0xFF4A90E2);
    case 'technique':
      return const Color(0xFF9B59B6);
    case 'fitness':
      return const Color(0xFFE74C3C);
    case 'recovery':
      return const Color(0xFF2ECC71);
    default:
      return const Color(0xFF34495E);
  }
}

IconData _getTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'ai-powered':
      return Icons.psychology;
    case 'data-driven':
      return Icons.analytics;
    case 'skill-building':
      return Icons.school;
    case 'consistency':
      return Icons.schedule;
    case 'motivation':
      return Icons.emoji_events;
    case 'endurance':
      return Icons.timer;
    case 'efficiency':
      return Icons.speed;
    case 'stroke':
      return Icons.pool;
    case 'technique':
      return Icons.auto_fix_high;
    case 'fitness':
      return Icons.fitness_center;
    case 'recovery':
      return Icons.spa;
    default:
      return Icons.star;
  }
}

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getFatigueColor(String fatigue) {
    switch (fatigue.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  
}