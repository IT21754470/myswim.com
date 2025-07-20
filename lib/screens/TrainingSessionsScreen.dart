import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/training_session.dart';
import '../services/training_session_service.dart';
import '../utils/stroke_utils.dart';
import 'add_training_session_screen.dart';

class TrainingSessionsScreen extends StatefulWidget {
  const TrainingSessionsScreen({super.key});

  @override
  State<TrainingSessionsScreen> createState() => _TrainingSessionsScreenState();
}

class _TrainingSessionsScreenState extends State<TrainingSessionsScreen> {
  List<TrainingSession> _sessions = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _sortBy = 'Date';

  @override
  void initState() {
    super.initState();
    _loadTrainingSessions();
  }

  Future<void> _loadTrainingSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessions = await TrainingSessionService.getUserTrainingSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading training sessions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<TrainingSession> get _filteredSessions {
    List<TrainingSession> filtered = _sessions;
    
    // Apply stroke filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((s) => s.strokeType == _selectedFilter).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'Date':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'Time':
        filtered.sort((a, b) => a.actualTime.compareTo(b.actualTime));
        break;
      case 'Distance':
        filtered.sort((a, b) => b.trainingDistance.compareTo(a.trainingDistance));
        break;
      case 'Pace':
        filtered.sort((a, b) => a.pacePer100m.compareTo(b.pacePer100m));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Training Sessions'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadTrainingSessions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          _buildStatsHeader(),
          
          // Filters and Sorting
          _buildFiltersAndSorting(),
          
          // Sessions List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredSessions.isEmpty
                    ? _buildEmptyState()
                    : _buildSessionsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTrainingSessionScreen(),
            ),
          );
          if (result == true) {
            _loadTrainingSessions();
          }
        },
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_sessions.isEmpty) return const SizedBox.shrink();
    
    final totalDistance = _sessions.totalDistance();
    final totalTime = _sessions.totalTrainingTime();
    final avgPace = _sessions.fold<double>(0, (sum, s) => sum + s.pacePer100m) / _sessions.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Sessions',
              _sessions.length.toString(),
              Icons.pool,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _buildStatItem(
              'Distance',
              '${(totalDistance / 1000).toStringAsFixed(1)}km',
              Icons.straighten,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          Expanded(
            child: _buildStatItem(
              'Avg Pace',
              '${avgPace.toStringAsFixed(1)}s/100m',
              Icons.speed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 8),
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

  Widget _buildFiltersAndSorting() {
    final strokes = ['All', ...StrokeUtils.getAllStrokes()];
    final sortOptions = ['Date', 'Time', 'Distance', 'Pace'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Stroke Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  icon: const Icon(Icons.filter_list, size: 16),
                  items: strokes.map((stroke) {
                    return DropdownMenuItem(
                      value: stroke,
                      child: Text(stroke, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort By
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  icon: const Icon(Icons.sort, size: 16),
                  items: sortOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text('Sort by $option', style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
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
          Text('Loading training sessions...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pool_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'All' 
                  ? 'No Training Sessions Yet'
                  : 'No $_selectedFilter Sessions',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All'
                  ? 'Start tracking your swimming progress by adding your first training session!'
                  : 'No training sessions found for $_selectedFilter. Try a different filter or add new sessions.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSessions.length,
      itemBuilder: (context, index) {
        final session = _filteredSessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(TrainingSession session) {
    final strokeColor = StrokeUtils.getStrokeColor(session.strokeType);
    final strokeIcon = StrokeUtils.getStrokeIcon(session.strokeType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSessionDetails(session),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: strokeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(strokeIcon, color: strokeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.strokeType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(session.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: strokeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${session.poolLength}m pool',
                        style: TextStyle(
                          fontSize: 10,
                          color: strokeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildSessionStat(
                        'Distance',
                        '${session.trainingDistance.toInt()}m',
                        Icons.straighten,
                      ),
                    ),
                    Expanded(
                      child: _buildSessionStat(
                        'Time',
                        StrokeUtils.formatTime(session.actualTime),
                        Icons.timer,
                      ),
                    ),
                    Expanded(
                      child: _buildSessionStat(
                        'Pace',
                        '${session.pacePer100m.toStringAsFixed(1)}s/100m',
                        Icons.speed,
                      ),
                    ),
                    Expanded(
                      child: _buildSessionStat(
                        'Laps',
                        session.laps.toString(),
                        Icons.repeat,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showSessionDetails(TrainingSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSessionDetailsModal(session),
    );
  }

  Widget _buildSessionDetailsModal(TrainingSession session) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StrokeUtils.getStrokeColor(session.strokeType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    StrokeUtils.getStrokeIcon(session.strokeType),
                    color: StrokeUtils.getStrokeColor(session.strokeType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.strokeType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(session.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.id != null)
                  IconButton(
                    onPressed: () => _deleteSession(session),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
              ],
            ),
          ),
          
          // Details
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildDetailRow('Distance', '${session.trainingDistance.toInt()} meters'),
                _buildDetailRow('Duration', '${session.sessionDuration.toInt()} minutes'),
                _buildDetailRow('Actual Time', StrokeUtils.formatTime(session.actualTime)),
                _buildDetailRow('Pace per 100m', '${session.pacePer100m.toStringAsFixed(2)} seconds'),
                _buildDetailRow('Laps', session.laps.toString()),
                _buildDetailRow('Pool Length', '${session.poolLength} meters'),
                if (session.avgHeartRate != null)
                  _buildDetailRow('Average Heart Rate', '${session.avgHeartRate!.toInt()} bpm'),
                if (session.restInterval != null)
                  _buildDetailRow('Rest Interval', '${session.restInterval!.toInt()} seconds'),
                if (session.baseTime != null)
                  _buildDetailRow('Base Time', StrokeUtils.formatTime(session.baseTime!)),
                _buildDetailRow('Calories Burned', '${session.calculateCaloriesBurned().toInt()} cal'),
                _buildDetailRow('Performance Rating', '${session.getPerformanceRating()}/5 stars'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(TrainingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this training session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && session.id != null) {
      try {
        await TrainingSessionService.deleteTrainingSession(session.id!);
        Navigator.of(context).pop(); // Close modal
        _loadTrainingSessions(); // Refresh list
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training session deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}