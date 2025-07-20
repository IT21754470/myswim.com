import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swimming_app/screens/add_training_session_screen.dart';
import '../models/training_session.dart';
import '../services/improvement_prediction_service.dart';
import '../services/training_session_service.dart';
import '../widgets/enhanced_daily_prediction_card.dart';
import '../widgets/mini_chart_painter.dart';
import '../utils/stroke_utils.dart';

class ImprovementPredictionScreen extends StatefulWidget {
  const ImprovementPredictionScreen({super.key});

  @override
  State<ImprovementPredictionScreen> createState() => _ImprovementPredictionScreenState();
}

class _ImprovementPredictionScreenState extends State<ImprovementPredictionScreen> 
    with SingleTickerProviderStateMixin {
  
  bool _isLoading = false;
  PredictionResponse? _predictionResponse;
  List<TrainingSession> _trainingHistory = [];
  int _daysToPredict = 7;
  String? _errorMessage;
  
  late TabController _tabController;
  final ImprovementPredictionService _predictionService = ImprovementPredictionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _predictionService.initialize();
    _loadTrainingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

 Future<void> _loadTrainingData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final sessions = await TrainingSessionService.getUserTrainingSessions();
    final userProfile = await TrainingSessionService.getUserProfile();
    
    final formattedSessions = sessions.map((session) {
      return TrainingSession(
        swimmerId: 1,
        poolLength: session.poolLength,
        date: session.date,
        strokeType: session.strokeType,
        trainingDistance: session.trainingDistance,
        sessionDuration: session.sessionDuration,
        pacePer100m: session.pacePer100m,
        laps: session.laps,
        avgHeartRate: session.avgHeartRate,
        restInterval: session.restInterval,
        baseTime: session.baseTime,
        actualTime: session.actualTime,
        gender: userProfile?['gender'] ?? 'Male',
      );
    }).toList();

    setState(() {
      _trainingHistory = formattedSessions;
    });

    // ✅ Only get predictions if user has training data
    if (_trainingHistory.isNotEmpty) {
      await _getPrediction();
    } else {
      // ✅ Clear any existing predictions for new users
      setState(() {
        _predictionResponse = null;
        _errorMessage = null;
      });
    }
    
  } catch (e) {
    print('❌ Error loading training data: $e');
    setState(() {
      _trainingHistory = [];
      _predictionResponse = null;
      _errorMessage = 'Error loading training data: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<void> _getPrediction() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictionResponse = null;
    });

    try {
      final response = await _predictionService.getPrediction(
        trainingHistory: _trainingHistory,
        daysToPredict: _daysToPredict,
      );

      if (mounted) {
        setState(() {
          _predictionResponse = response;
          if (response.status != 'success') {
            _errorMessage = response.error ?? 'Prediction failed';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting prediction: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: Column(
      children: [
        _buildEnhancedHeader(),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _trainingHistory.isEmpty // ✅ Check for no training data first
                  ? _buildNoDataState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildPredictionContent(),
        ),
      ],
    ),
  );
}

Widget _buildNoDataState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pool_outlined,
            size: 80,
            color: Colors.blue[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Start Your Swimming Journey!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4A90E2),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Add your first training session to see performance predictions and track your progress.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // ✅ Add Training Session Button
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddTrainingSessionScreen(),
                ),
              );
              
              // Refresh data if a session was added
              if (result == true) {
                _loadTrainingData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Training Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ✅ Refresh Button
          TextButton.icon(
            onPressed: _loadTrainingData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4A90E2),
            ),
          ),
        ],
      ),
    ),
  );
}
 Widget _buildEnhancedHeader() {
  final bool hasData = _trainingHistory.isNotEmpty;
  
  return Container(
    padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4A90E2),
          Color(0xFF357ABD),
        ],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with back button
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
              onPressed: _loadTrainingData,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        
        // ✅ Only show period selector and stats if there's data
        if (hasData) ...[
          const SizedBox(height: 20),
          
          // Period selector
          Container(
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
          ),
          
          const SizedBox(height: 20),
          
          // Quick stats
          if (_predictionResponse?.futurePredictions != null)
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    'Peak Day',
                    _getPeakDay(),
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    'Potential',
                    '+${_getAverageImprovement().toStringAsFixed(1)}s faster',
                    Icons.rocket_launch,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    'Confidence',
                    '${(_predictionResponse!.futurePredictions!.modelAccuracy * 100).toInt()}%',
                    Icons.psychology,
                    Colors.purple,
                  ),
                ),
              ],
            ),
        ],
      ],
    ),
  );
}

  Widget _buildPeriodTab(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          int days = int.parse(text.split(' ')[0]);
          if (days != _daysToPredict) {
            setState(() {
              _daysToPredict = days;
            });
            _getPrediction();
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

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
          SizedBox(height: 16),
          Text('Analyzing your swimming data...'),
          SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Prediction Analysis',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                _predictionService.forceOfflineMode();
                await _getPrediction();
              },
              icon: const Icon(Icons.offline_bolt),
              label: const Text('Use Offline Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadTrainingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionContent() {
    return Column(
      children: [
        // Tab Navigation
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4A90E2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4A90E2),
            tabs: const [
              Tab(text: 'Predictions'),
              Tab(text: 'Insights'),
              Tab(text: 'Recommendations'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPredictionsTab(),
              _buildInsightsTab(),
              _buildRecommendationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    if (_predictionResponse?.futurePredictions == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No predictions available yet'),
          ],
        ),
      );
    }

    final futurePredictions = _predictionResponse!.futurePredictions!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Model Accuracy Card
        _buildModelAccuracyCard(futurePredictions.modelAccuracy),
        
        const SizedBox(height: 20),
        
        // Daily Predictions
        ...futurePredictions.byDate.entries.map((entry) => 
          EnhancedDailyPredictionCard(
            date: entry.key,
            predictions: entry.value,
          )
        ).toList(),
      ],
    );
  }

  Widget _buildModelAccuracyCard(double accuracy) {
    final percentage = (accuracy * 100).toStringAsFixed(1);
    final color = accuracy > 0.8 ? Colors.green : accuracy > 0.6 ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediction Accuracy',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your training patterns',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  accuracy > 0.8 ? 'Excellent' : accuracy > 0.6 ? 'Good' : 'Fair',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_predictionResponse?.swimmerSummaries == null) {
      return const Center(
        child: Text('No insights available'),
      );
    }

    final summaries = _predictionResponse!.swimmerSummaries!;
    final modelInfo = _predictionResponse!.modelInfo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...summaries.entries.map((entry) => 
          _buildSwimmerSummaryCard(entry.key, entry.value)
        ).toList(),
        
        const SizedBox(height: 16),
        
     
      ],
    );
  }

  Widget _buildSwimmerSummaryCard(String swimmerId, SwimmerSummary summary) {
    final trendColor = summary.trend.contains('improving') ? Colors.green :
                       summary.trend.contains('declining') ? Colors.red : Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              const Text(
                'Performance Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Average Improvement'),
              Text(
                '${summary.averageImprovement.toStringAsFixed(2)}s per session',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Predictions'),
              Text(
                '${summary.predictionCount} sessions',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Performance Trend'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  summary.trend,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


          
          

  Widget _buildRecommendationsTab() {
    return const Center(
      child: Text('Recommendations coming soon...'),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Date unavailable';
    }
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getErrorMessage() {
    if (_errorMessage?.contains('sklearn') == true) {
      return 'Our prediction server is updating. We\'ll use smart local analysis instead!';
    } else if (_errorMessage?.contains('timeout') == true) {
      return 'Connection timeout. Let\'s analyze your data locally.';
    } else {
      return 'Switching to offline prediction mode...';
    }
  }

  String _getPeakDay() {
    if (_predictionResponse?.futurePredictions?.byDate.isNotEmpty == true) {
      double maxImprovement = 0;
      String peakDate = '';
      
      _predictionResponse!.futurePredictions!.byDate.forEach((date, predictions) {
        double totalImprovement = predictions.fold(0, (sum, p) => sum + p.improvement);
        if (totalImprovement > maxImprovement) {
          maxImprovement = totalImprovement;
          peakDate = date;
        }
      });
      
      try {
        final date = DateTime.parse(peakDate);
        return DateFormat('MMM d').format(date);
      } catch (e) {
        return 'TBD';
      }
    }
    return 'TBD';
  }

  double _getAverageImprovement() {
    if (_predictionResponse?.futurePredictions?.byDate.isNotEmpty == true) {
      double totalImprovement = 0;
      int count = 0;
      
      _predictionResponse!.futurePredictions!.byDate.values.forEach((predictions) {
        predictions.forEach((prediction) {
          totalImprovement += prediction.improvement;
          count++;
        });
      });
      
      return count > 0 ? totalImprovement / count : 0;
    }
    return 0;
  }
}