import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://fatigue-prediction.onrender.com';
  
  static Future<Map<String, dynamic>?> getPrediction({
    required String swimmerId,
    required String strokeType,
    required double predictedImprovement,
    required String fatigueLevel,
  }) async {
    try {
      print('🌐 Calling recommendation API...');
      print('   Swimmer: $swimmerId');
      print('   Stroke: $strokeType');
      print('   Improvement: $predictedImprovement');
      print('   Fatigue: $fatigueLevel');
      
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'swimmer_id': swimmerId,
          'stroke_type': strokeType,
          'predicted_improvement': predictedImprovement,
          'fatigue_level': fatigueLevel,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ API returned: ${data.keys}');
        return data;
      } else {
        print('❌ API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ API exception: $e');
      return null;
    }
  }

  // ✅ FIX: Always return bool, never null
  static Future<bool> checkHealth() async {
    try {
      print('🏥 Checking API health...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      final isHealthy = response.statusCode == 200;
      print(isHealthy ? '✅ API is healthy' : '⚠️  API returned ${response.statusCode}');
      return isHealthy;
      
    } catch (e) {
      print('❌ Health check failed: $e');
      return false; // ✅ Always return false on error, not null
    }
  }
}