// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
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
      final url = Uri.parse('$baseUrl/predict');
      
      final requestBody = {
        "swimmer_id": swimmerId,
        "stroke_type": strokeType,
        "predicted_improvement": predictedImprovement,
        "fatigue_level": fatigueLevel,
      };
      
      print('Making API request to: $url');
      print('Request body: $requestBody');
      
      // Reduced timeout to 8 seconds for faster fallback
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⏰ API request timed out - using local recommendations');
          throw TimeoutException('API timeout', const Duration(seconds: 8));
        },
      );
      
      print('✅ Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        print('✅ API Success: Got recommendation');
        return responseData;
      } else {
        print('❌ API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout: ${e.message} - falling back to local');
      return null;
    } on SocketException catch (e) {
      print('🌐 Network error: $e');
      return null;
    } on HttpException catch (e) {
      print('📡 HTTP error: $e');
      return null;
    } catch (e) {
      print('💥 Unexpected error: $e');
      return null;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  const TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message';
}