import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swimming_app/services/fatigur_prediction_service.dart';
import '../models/training_session.dart';
import '../services/fatigur_prediction_service.dart';
import '../services/training_session_service.dart';

class FatiguePredictionScreen extends StatefulWidget {
  const FatiguePredictionScreen({super.key});

  @override
  State<FatiguePredictionScreen> createState() => _FatiguePredictionScreenState();
}

class _FatiguePredictionScreenState extends State<FatiguePredictionScreen>
    with SingleTickerProviderStateMixin {

  bool _isLoading = false;
  bool _isConnectionTesting = false;
  bool _backendConnected = false;
  FatiguePredictionResponse? _predictionResponse;
  List<TrainingSession> _trainingHistory = [];
  int _daysToPredict = 7;
  String? _errorMessage;

  late TabController _tabController;
  final FatiguePredictionService _predictionService = FatiguePredictionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _predictionService.initialize();
    _testBackendConnection();
    _loadTrainingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _testBackendConnection() async {
    setState(() {
      _isConnectionTesting = true;
    });

    try {
      final isConnected = await _predictionService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
        _isConnectionTesting = false;
      });

      print('🏥 Fatigue backend connection: ${isConnected ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      setState(() {
        _backendConnected = false;
        _isConnectionTesting = false;
      });
      print('❌ Fatigue connection test error: $e');
    }
  }

  Future<void> _loadTrainingData() async {
    print('🔄 Loading training data for fatigue prediction...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await TrainingSessionService.getUserTrainingSessions();
      print('📊 Loaded ${sessions.length} training sessions for fatigue analysis');

      setState(() {
        _trainingHistory = sessions;
      });

      if (_trainingHistory.isNotEmpty) {
        await _getFatiguePrediction();
      } else {
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

  Future<void> _getFatiguePrediction() async {
    print('🚀 Starting fatigue prediction request...');
    print('📊 Training history: ${_trainingHistory.length} sessions');
    print('📅 Days to predict: $_daysToPredict');

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _predictionResponse = null;
    });

    try {
      final response = await _predictionService.getFatiguePrediction(
        trainingHistory: _trainingHistory,
        daysToPredict: _daysToPredict,
      );

      print('✅ Got fatigue response: ${response.status}');
      print('🎯 Fatigue predictions available: ${response.predictions?.length ?? 0} days');

      if (mounted) {
        setState(() {
          _predictionResponse = response;
          if (response.status != 'success') {
            _errorMessage = response.error ?? 'Fatigue prediction failed';
          }
        });
      }
    } catch (e) {
      print('❌ Fatigue prediction error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting fatigue prediction: $e';
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
                : _trainingHistory.isEmpty
                    ? _buildNoDataState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildPredictionContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final bool hasData = _trainingHistory.isNotEmpty;
    final bool isOnline = !_predictionService.isOfflineMode;

    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFfa709a), // Pink
            Color(0xFFfee140), // Yellow
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Fatigue Prediction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Network Status Indicator
              if (_isConnectionTesting)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _testBackendConnection,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOnline && _backendConnected)
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (isOnline && _backendConnected) ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (isOnline && _backendConnected) ? 'AI' : 'Local',
                          style: TextStyle(
                            color: (isOnline && _backendConnected) ? Colors.green : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              IconButton(
                onPressed: () {
                  _testBackendConnection();
                  _loadTrainingData();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),

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
            if (_predictionResponse?.predictions != null)
              _buildFatigueQuickStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildFatigueQuickStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickStat('Current', '${_getCurrentFatigue().toStringAsFixed(1)}', Icons.battery_alert, Colors.amber),
                _buildQuickStat('Peak Day', _getPeakFatigueDay(), Icons.warning, Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickStat('Average', '${_getAverageFatigue().toStringAsFixed(1)}', Icons.analytics, Colors.blue),
                _buildQuickStat('Risk Level', _getHighestRisk(), Icons.shield, Colors.purple),
              ],
            ),
          ],
        );
      },
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
            _getFatiguePrediction();
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
              color: isSelected ? const Color(0xFFfa709a) : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8,
              ),
              textAlign: TextAlign.center,
            ),
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
              Icons.battery_alert_outlined,
              size: 80,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No Training Data Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFfa709a),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'No training sessions are available for fatigue analysis. Please add some training data to see fatigue predictions.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _loadTrainingData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfa709a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFfa709a)),
          ),
          SizedBox(height: 16),
          Text('Analyzing your fatigue levels...'),
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
              Icons.battery_alert_outlined,
              size: 64,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Fatigue Analysis',
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
                await _getFatiguePrediction();
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
              onPressed: () {
                _testBackendConnection();
                _loadTrainingData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfa709a),
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
            labelColor: const Color(0xFFfa709a),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFfa709a),
            tabs: const [
              Tab(text: 'Daily Fatigue'),
              Tab(text: 'Risk Analysis'),
              Tab(text: 'Recommendations'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFatigueTab(),
              _buildRiskTab(),
              _buildRecommendationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFatigueTab() {
    if (_predictionResponse?.predictions == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.battery_alert_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No fatigue predictions available yet'),
          ],
        ),
      );
    }

    final predictions = _predictionResponse!.predictions!.values.toList();
    predictions.sort((a, b) => a.date.compareTo(b.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: predictions.length,
      itemBuilder: (context, index) {
        return _buildDailyFatigueCard(predictions[index]);
      },
    );
  }

  Widget _buildDailyFatigueCard(FatigueDayPrediction prediction) {
    final fatigueLevel = prediction.fatigueLevel;
    final fatigueColor = _getFatigueColor(fatigueLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Row(
              children: [
                Icon(Icons.calendar_today, color: fatigueColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDate(prediction.date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: fatigueColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRiskColor(prediction.riskLevel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prediction.riskLevel,
                    style: TextStyle(
                      color: _getRiskColor(prediction.riskLevel),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Fatigue Level
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fatigue Level',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${fatigueLevel.toStringAsFixed(1)}/10',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: fatigueColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFatigueBar(fatigueLevel),
                        ],
                      ),
                    ],
                  ),
                ),
                if (prediction.recoveryNeeded)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.hotel, color: Colors.orange, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'Recovery\nNeeded',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Recommended Intensity
            Row(
              children: [
                Icon(Icons.fitness_center, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Recommended Intensity: ${prediction.recommendedIntensity.toStringAsFixed(1)}/10',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatigueBar(double fatigueLevel) {
    return Expanded(
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          widthFactor: fatigueLevel / 10,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: _getFatigueColor(fatigueLevel),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskTab() {
    if (_predictionResponse?.predictions == null) {
      return const Center(child: Text('No risk analysis available'));
    }

    final predictions = _predictionResponse!.predictions!.values.toList();
    predictions.sort((a, b) => a.date.compareTo(b.date));

    final highRiskDays = predictions.where((p) => p.riskLevel == 'High').length;
    final mediumRiskDays = predictions.where((p) => p.riskLevel == 'Medium').length;
    final lowRiskDays = predictions.where((p) => p.riskLevel == 'Low').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Risk Overview Card
        Container(
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
              const Text(
                'Risk Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildRiskSummaryRow('High Risk Days', highRiskDays, Colors.red),
              const SizedBox(height: 8),
              _buildRiskSummaryRow('Medium Risk Days', mediumRiskDays, Colors.orange),
              const SizedBox(height: 8),
              _buildRiskSummaryRow('Low Risk Days', lowRiskDays, Colors.green),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Risk Timeline
        ...predictions.map((prediction) => _buildRiskTimelineItem(prediction)).toList(),
      ],
    );
  }

  Widget _buildRiskSummaryRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        Text(
          '$count days',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskTimelineItem(FatigueDayPrediction prediction) {
    final riskColor = _getRiskColor(prediction.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: riskColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDate(prediction.date),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            'Fatigue: ${prediction.fatigueLevel.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_predictionResponse?.recommendations == null) {
      return const Center(child: Text('No recommendations available'));
    }

    final recommendations = _predictionResponse!.recommendations!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // General Recommendations
        Container(
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
                  const Icon(Icons.lightbulb, color: Color(0xFFfa709a)),
                  const SizedBox(width: 8),
                  const Text(
                    'Recommendations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ...recommendations.map((recommendation) => _buildRecommendationItem(recommendation)).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(String recommendation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFfa709a),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getFatigueColor(double fatigueLevel) {
    if (fatigueLevel < 4) return Colors.green;
    if (fatigueLevel < 7) return Colors.orange;
    return Colors.red;
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      return 'Our fatigue prediction server is updating. We\'ll use smart local analysis instead!';
    } else if (_errorMessage?.contains('timeout') == true) {
      return 'Connection timeout. Let\'s analyze your data locally.';
    } else if (_errorMessage?.contains('connection') == true) {
      return 'Unable to connect to fatigue server. Using offline analysis.';
    } else {
      return 'Switching to offline fatigue mode...';
    }
  }

  double _getCurrentFatigue() {
    if (_predictionResponse?.predictions?.isEmpty ?? true) return 5.0;
    final predictions = _predictionResponse!.predictions!.values.toList();
    predictions.sort((a, b) => a.date.compareTo(b.date));
    return predictions.first.fatigueLevel;
  }

  String _getPeakFatigueDay() {
    if (_predictionResponse?.peakFatigueDate != null) {
      try {
        final date = DateTime.parse(_predictionResponse!.peakFatigueDate!);
        return DateFormat('MMM d').format(date);
      } catch (e) {
        return 'TBD';
      }
    }
    return 'TBD';
  }

  double _getAverageFatigue() {
    return _predictionResponse?.averageFatigue ?? 5.0;
  }

  String _getHighestRisk() {
    if (_predictionResponse?.predictions?.isEmpty ?? true) return 'Medium';
    final predictions = _predictionResponse!.predictions!.values.toList();
    if (predictions.any((p) => p.riskLevel == 'High')) return 'High';
    if (predictions.any((p) => p.riskLevel == 'Medium')) return 'Medium';
    return 'Low';
  }
}