import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class PredictionService {
  final String base;
  const PredictionService(this.base);

  Future<Map<String, dynamic>> predict({
    String? swimmerId, // optional—defaults to Firebase uid
    String? name,      // optional—use profile if you have it
    required String distance,
    required String stroke,
    required double waterTemp,
    required double humidityPct,
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final uri = Uri.parse('$base/api/predict');
    final body = {
      'swimmerId': swimmerId ?? user?.uid,
      'name': name,
      'distance': distance,
      'stroke': stroke,
      'waterTemp': waterTemp,
      'humidityPct': humidityPct,
      'date': date.toIso8601String(),
    };

    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode >= 400) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

// Pass this at build time with --dart-define
const String _apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://timeprediction-backend.onrender.com', // fallback
);

final predictionService = PredictionService(_apiBase);
