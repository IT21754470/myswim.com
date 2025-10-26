// lib/screens/improvement_prediction_screen.dart
import 'package:flutter/material.dart';
import '../widgets/enhanced_improvement_prediction_card.dart';
import '../widgets/improvement_trend_chart.dart';
import '../services/improvement_prediction_service.dart';
import '../models/improvement_prediction.dart';
class Recommendation {
  final String text;
  final IconData icon;
  final String priority; // 'high', 'medium', 'normal'
  
  Recommendation({
    required this.text,
    required this.icon,
    this.priority = 'normal',
  });
}
class ImprovementPredictionScreen extends StatefulWidget {
  const ImprovementPredictionScreen({super.key});

  @override
  State<ImprovementPredictionScreen> createState() => 
      _ImprovementPredictionScreenState();
}

class _ImprovementPredictionScreenState extends State<ImprovementPredictionScreen>
    with SingleTickerProviderStateMixin {
  
  bool _isLoading = false;
  Map<String, List<ImprovementPrediction>> _historicalPredictions = {};
  Map<String, List<ImprovementPrediction>> _futurePredictions = {};
  int _daysToPredict = 7;
  
  String? _errorMessage;
  
  late TabController _tabController;
  final ImprovementPredictionService _service = ImprovementPredictionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service.initialize();
    _loadPredictions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPredictions() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    print('🔄 Loading predictions for $_daysToPredict days...');
    
    final response = await _service.getImprovementPrediction(
      daysToPredict: _daysToPredict,
    );

    print('✅ Got response:');
    print('  Historical dates: ${response.historicalPredictions.keys.length}');
    print('  Future dates: ${response.futurePredictions.keys.length}');

    setState(() {
      _historicalPredictions = response.historicalPredictions;
      // Use helper that reads _daysToPredict from state; remove extra argument.
      _futurePredictions = _getNextFutureDays(response);
    });

    if (_historicalPredictions.isEmpty && _futurePredictions.isEmpty) {
      setState(() {
        _errorMessage = 'No predictions available. Please add training sessions first.';
      });
    }
  } catch (e) {
    print('❌ Error loading predictions: $e');
    setState(() {
      _errorMessage = e.toString();
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Performance Prediction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadPredictions,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPeriodSelector(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodTab('7 Days', _daysToPredict == 7),
          _buildPeriodTab('14 Days', _daysToPredict == 14),
          _buildPeriodTab('30 Days', _daysToPredict == 30),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final days = int.parse(text.split(' ')[0]);
          if (days != _daysToPredict) {
            setState(() => _daysToPredict = days);
            _loadPredictions();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4A90E2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4A90E2),
            tabs: const [
              Tab(text: 'Timeline'),
              Tab(text: 'Trends'),
              Tab(text: 'Analysis'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTimelineTab(),
              _buildTrendsTab(),
              _buildAnalysisTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab() {
    final allPredictions = <String, List<ImprovementPrediction>>{};
    allPredictions.addAll(_historicalPredictions);
    allPredictions.addAll(_futurePredictions);

    if (allPredictions.isEmpty) {
      return const Center(child: Text('No predictions available'));
    }

    final sortedDates = allPredictions.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final predictions = allPredictions[date]!;
        return EnhancedImprovementPredictionCard(
          date: date,
          predictions: predictions,
        );
      },
    );
  }

  Widget _buildTrendsTab() {
    final allPredictions = <String, List<ImprovementPrediction>>{};
    allPredictions.addAll(_historicalPredictions);
    allPredictions.addAll(_futurePredictions);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ImprovementTrendChart(predictionsByDate: allPredictions),
        const SizedBox(height: 16),
        _buildStrokeBreakdown(),
      ],
    );
  }

  Widget _buildStrokeBreakdown() {
    final strokeStats = <String, List<double>>{};
    
    _historicalPredictions.forEach((date, predictions) {
      for (var pred in predictions) {
        strokeStats.putIfAbsent(pred.stroke, () => []).add(pred.improvement);
      }
    });

    _futurePredictions.forEach((date, predictions) {
      for (var pred in predictions) {
        strokeStats.putIfAbsent(pred.stroke, () => []).add(pred.improvement);
      }
    });

    if (strokeStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No stroke data available')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stroke Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...strokeStats.entries.map((entry) {
            final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
            return _buildStrokeStatRow(entry.key, avg);
          }),
        ],
      ),
    );
  }

  Widget _buildStrokeStatRow(String stroke, double avgImprovement) {
    final color = avgImprovement > 0 ? Colors.green : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stroke,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${avgImprovement > 0 ? '+' : ''}${avgImprovement.toStringAsFixed(2)}s',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTopFactorsCard(),
        const SizedBox(height: 16),
        _buildRecommendationsCard(),
      ],
    );
  }

  Widget _buildTopFactorsCard() {
    final factorCount = <String, int>{};
    
    _historicalPredictions.forEach((date, predictions) {
      for (var pred in predictions) {
        for (var factor in pred.topFactors) {
          factorCount[factor] = (factorCount[factor] ?? 0) + 1;
        }
      }
    });

    _futurePredictions.forEach((date, predictions) {
      for (var pred in predictions) {
        for (var factor in pred.topFactors) {
          factorCount[factor] = (factorCount[factor] ?? 0) + 1;
        }
      }
    });

    final sortedFactors = factorCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF4A90E2)),
              SizedBox(width: 8),
              Text(
                'Most Influential Factors',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedFactors.isEmpty)
            const Text('No factor data available')
          else
            ...sortedFactors.take(5).map((entry) => 
              _buildFactorRow(entry.key, entry.value)
            ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String factor, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              factor,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count times',
              style: const TextStyle(
                color: Color(0xFF4A90E2),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
 Widget _buildRecommendationsCard() {
    final recommendations = _generateDynamicRecommendations();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recommendations.isEmpty)
            const Text('Not enough data for recommendations')
          else
            ...recommendations.map((rec) => _buildRecommendationItem(
              rec.text,
              rec.icon,
              priority: rec.priority,
            )),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text, IconData icon, {String priority = 'normal'}) {
    Color iconColor;
    Color bgColor;
    
    switch (priority) {
      case 'high':
        iconColor = Colors.red[700]!;
        bgColor = Colors.red[50]!;
        break;
      case 'medium':
        iconColor = Colors.amber[700]!;
        bgColor = Colors.amber[50]!;
        break;
      default:
        iconColor = Colors.green[700]!;
        bgColor = Colors.green[50]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  List<Recommendation> _generateDynamicRecommendations() {
    final recommendations = <Recommendation>[];
    
    // Collect all predictions
    final allPredictions = <ImprovementPrediction>[];
    _futurePredictions.forEach((date, preds) => allPredictions.addAll(preds));
    _historicalPredictions.forEach((date, preds) => allPredictions.addAll(preds));
    
    if (allPredictions.isEmpty) {
      return recommendations;
    }

    // 1. Analyze overall trend
    final avgImprovement = allPredictions
        .map((p) => p.improvement)
        .reduce((a, b) => a + b) / allPredictions.length;
    
    final decliningCount = allPredictions.where((p) => p.improvement < -0.1).length;
    final improvingCount = allPredictions.where((p) => p.improvement > 0.1).length;
    
    if (decliningCount > improvingCount) {
      recommendations.add(Recommendation(
        text: 'Performance is trending downward. Consider reviewing your training plan and recovery schedule.',
        icon: Icons.trending_down,
        priority: 'high',
      ));
    } else if (improvingCount > decliningCount) {
      recommendations.add(Recommendation(
        text: 'Great progress! Keep up your current training routine.',
        icon: Icons.trending_up,
        priority: 'normal',
      ));
    }

    // 2. Analyze most common factors
    final factorCount = <String, int>{};
    for (var pred in allPredictions) {
      for (var factor in pred.topFactors) {
        factorCount[factor] = (factorCount[factor] ?? 0) + 1;
      }
    }
    
    final topFactors = factorCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // 3. Generate recommendations based on top factors
    if (topFactors.isNotEmpty) {
      final topFactor = topFactors.first.key.toLowerCase();
      
      if (topFactor.contains('intensity')) {
        final lowIntensityCount = allPredictions
            .where((p) => p.reasons.any((r) => r.toLowerCase().contains('low') && r.toLowerCase().contains('intensity')))
            .length;
        
        if (lowIntensityCount > allPredictions.length / 2) {
          recommendations.add(Recommendation(
            text: 'Training intensity is frequently low. Consider increasing workout intensity gradually.',
            icon: Icons.fitness_center,
            priority: 'high',
          ));
        }
      }
      
      if (topFactor.contains('heart') || topFactor.contains('hr')) {
        recommendations.add(Recommendation(
          text: 'Heart rate is a key factor. Monitor your HR zones and ensure proper warm-up.',
          icon: Icons.favorite,
          priority: 'medium',
        ));
      }
      
      if (topFactor.contains('pace')) {
        final fastPaceCount = allPredictions
            .where((p) => p.reasons.any((r) => r.toLowerCase().contains('fast') && r.toLowerCase().contains('pace')))
            .length;
        
        if (fastPaceCount > allPredictions.length / 3) {
          recommendations.add(Recommendation(
            text: 'Your pace is often fast. Consider mixing in some slower, technique-focused sessions.',
            icon: Icons.speed,
            priority: 'medium',
          ));
        }
      }
      
      if (topFactor.contains('distance') || topFactor.contains('volume')) {
        final lowVolumeCount = allPredictions
            .where((p) => p.reasons.any((r) => r.toLowerCase().contains('low') && (r.toLowerCase().contains('distance') || r.toLowerCase().contains('volume'))))
            .length;
        
        if (lowVolumeCount > allPredictions.length / 3) {
          recommendations.add(Recommendation(
            text: 'Training volume is often low. Gradually increase your total distance.',
            icon: Icons.straighten,
            priority: 'medium',
          ));
        }
      }
      
      if (topFactor.contains('session') || topFactor.contains('duration')) {
        final shortSessionCount = allPredictions
            .where((p) => p.reasons.any((r) => r.toLowerCase().contains('short') && r.toLowerCase().contains('session')))
            .length;
        
        if (shortSessionCount > allPredictions.length / 3) {
          recommendations.add(Recommendation(
            text: 'Sessions are often short. Try extending your training duration for better results.',
            icon: Icons.access_time,
            priority: 'medium',
          ));
        }
      }
      
      if (topFactor.contains('rest')) {
        recommendations.add(Recommendation(
          text: 'Rest intervals impact your performance. Optimize recovery time between sets.',
          icon: Icons.hotel,
          priority: 'medium',
        ));
      }
    }

    // 4. Stroke-specific recommendations
    final strokePerformance = <String, double>{};
    for (var pred in allPredictions) {
      strokePerformance[pred.stroke] = (strokePerformance[pred.stroke] ?? 0) + pred.improvement;
    }
    
    if (strokePerformance.isNotEmpty) {
      final worstStroke = strokePerformance.entries
          .reduce((a, b) => a.value < b.value ? a : b);
      
      if (worstStroke.value < -0.5) {
        recommendations.add(Recommendation(
          text: '${worstStroke.key} needs attention. Focus on technique drills for this stroke.',
          icon: Icons.pool,
          priority: 'high',
        ));
      }
    }

    // 5. General health recommendations
    if (allPredictions.any((p) => p.reasons.any((r) => r.toLowerCase().contains('elevated') && r.toLowerCase().contains('heart')))) {
      recommendations.add(Recommendation(
        text: 'Elevated heart rate detected. Ensure adequate warm-up and cool-down.',
        icon: Icons.favorite_border,
        priority: 'medium',
      ));
    }

    // 6. Recovery recommendation if performance declining
    if (avgImprovement < -0.2) {
      recommendations.add(Recommendation(
        text: 'Consider taking a rest day. Recovery is crucial for performance improvement.',
        icon: Icons.bed,
        priority: 'high',
      ));
    }

    // Limit to top 5 recommendations
    return recommendations.take(5).toList();
  }

// Return only the next N future days from the response, using the current _daysToPredict
Map<String, List<ImprovementPrediction>> _getNextFutureDays(
  ImprovementPredictionResponse response,
) {
  final days = _daysToPredict;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Get only future dates (after today)
  final futureDates = Map.fromEntries(
    response.futurePredictions.entries.where((entry) {
      final predictionDate = DateTime.parse(entry.key);
      return predictionDate.isAfter(today);
    }),
  );

  // Sort dates and take the requested number of days
  final sortedDates = futureDates.keys.toList()..sort();
  final nextDates = sortedDates.take(days).toList();

  print('🔮 Filtered ${nextDates.length} future days from ${response.futurePredictions.length} total dates');

  return Map.fromEntries(
    nextDates.map((date) => MapEntry(date, futureDates[date]!)),
  );
}}

_buildErrorState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error, color: Colors.red, size: 64),
        SizedBox(height: 16),
        Text('An error occurred while fetching predictions.',
            style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}