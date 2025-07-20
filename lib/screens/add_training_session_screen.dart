import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swimming_app/models/user_profile.dart';
import 'package:swimming_app/services/profile_service.dart';
import 'package:swimming_app/services/training_session_service.dart';
import '../models/training_session.dart';
import '../utils/stroke_utils.dart';

class AddTrainingSessionScreen extends StatefulWidget {
  const AddTrainingSessionScreen({super.key});

  @override
  State<AddTrainingSessionScreen> createState() => _AddTrainingSessionScreenState();
}

class _AddTrainingSessionScreenState extends State<AddTrainingSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trainingDistanceController = TextEditingController();
  final _sessionDurationController = TextEditingController();
  final _lapsController = TextEditingController();
  final _avgHeartRateController = TextEditingController();
  final _restIntervalController = TextEditingController();
  final _baseTimeController = TextEditingController();
  final _actualTimeController = TextEditingController();

  String _selectedStroke = 'Freestyle';
  int _selectedPoolLength = 25;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add Training Session'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              'Session Details',
              Icons.pool,
              [
                _buildDateSelector(),
                const SizedBox(height: 16),
                _buildStrokeSelector(),
                const SizedBox(height: 16),
                _buildPoolLengthSelector(),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              'Training Metrics',
              Icons.fitness_center,
              [
                _buildTextField(
                  controller: _trainingDistanceController,
                  label: 'Training Distance (m)',
                  hint: 'e.g., 1000',
                  icon: Icons.straighten,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _sessionDurationController,
                  label: 'Session Duration (minutes)',
                  hint: 'e.g., 45',
                  icon: Icons.timer,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lapsController,
                  label: 'Number of Laps',
                  hint: 'e.g., 40',
                  icon: Icons.repeat,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              'Performance Data',
              Icons.analytics,
              [
                _buildTextField(
                  controller: _avgHeartRateController,
                  label: 'Average Heart Rate (bpm)',
                  hint: 'e.g., 150',
                  icon: Icons.favorite,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _restIntervalController,
                  label: 'Rest Interval (seconds)',
                  hint: 'e.g., 30',
                  icon: Icons.pause,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _baseTimeController,
                  label: 'Base Time (seconds)',
                  hint: 'e.g., 120.5',
                  icon: Icons.timer_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _actualTimeController,
                  label: 'Actual Time (seconds)',
                  hint: 'e.g., 118.2',
                  icon: Icons.schedule,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF4A90E2), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2A5298),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (keyboardType == TextInputType.number || 
            keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Training Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildStrokeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stroke Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: StrokeUtils.getAllStrokes().map((stroke) {
            final isSelected = _selectedStroke == stroke;
            return ChoiceChip(
              label: Text(stroke),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedStroke = stroke;
                });
              },
              selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPoolLengthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pool Length',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [25, 50].map((length) {
            final isSelected = _selectedPoolLength == length;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${length}m'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPoolLength = length;
                    });
                  },
                  selectedColor: const Color(0xFF4A90E2).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Training Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
  });

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    print('📝 Saving training session for user: ${user.uid}');

    final trainingDistance = double.parse(_trainingDistanceController.text);
    final sessionDuration = double.parse(_sessionDurationController.text);
    final actualTime = double.parse(_actualTimeController.text);
    final pacePer100m = (actualTime / trainingDistance) * 100;

    // ✅ First, ensure user has a profile
    var userProfile = await ProfileService.getUserProfile();
    if (userProfile == null) {
      print('📝 Creating new user profile...');
      userProfile = UserProfile(
        name: user.displayName ?? user.email?.split('@')[0] ?? 'Swimmer',
        gender: 'Male',
        totalSessions: 0,
        totalDistance: 0.0,
        totalHours: 0,
        createdAt: DateTime.now(),
      );
      await ProfileService.saveUserProfile(userProfile);
      print('✅ Default profile created');
    }

    // ✅ Save the training session
    final trainingSession = {
      'userId': user.uid,
      'swimmerId': 1,
      'poolLength': _selectedPoolLength,
      'date': _selectedDate.toIso8601String(),
      'strokeType': _selectedStroke,
      'trainingDistance': trainingDistance,
      'sessionDuration': sessionDuration,
      'pacePer100m': pacePer100m,
      'laps': int.parse(_lapsController.text),
      'avgHeartRate': _avgHeartRateController.text.isNotEmpty 
          ? double.parse(_avgHeartRateController.text) : null,
      'restInterval': _restIntervalController.text.isNotEmpty 
          ? double.parse(_restIntervalController.text) : null,
      'baseTime': _baseTimeController.text.isNotEmpty 
          ? double.parse(_baseTimeController.text) : null,
      'actualTime': actualTime,
      'gender': userProfile.gender ?? 'Male',
      'createdAt': FieldValue.serverTimestamp(),
    };

    print('💾 Saving session data...');
    final docRef = await FirebaseFirestore.instance
        .collection('training_sessions')
        .add(trainingSession);

    print('✅ Session saved with ID: ${docRef.id}');

    // ✅ Update profile stats - this is the critical part
    print('📊 Updating profile stats...');
    
    // Calculate new totals
    final newSessionCount = userProfile.totalSessions + 1;
    final newTotalDistance = userProfile.totalDistance + (trainingDistance / 1000); // Convert to km
    final newTotalHours = userProfile.totalHours + (sessionDuration / 60).round(); // Convert to hours

    // Update the profile with new stats
    final updatedProfile = userProfile.copyWith(
      totalSessions: newSessionCount,
      totalDistance: newTotalDistance,
      totalHours: newTotalHours,
      updatedAt: DateTime.now(),
    );

    await ProfileService.saveUserProfile(updatedProfile);
    
    print('✅ Profile stats updated: $newSessionCount sessions, ${newTotalDistance}km, ${newTotalHours}h');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Training session saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // ✅ Return true to indicate success
    }
  } catch (e) {
    print('❌ Error saving session: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}}