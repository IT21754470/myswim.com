// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart';

class ApiClient {
  final String baseUrl;
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? kApiBaseUrl;

  Map<String, String> get _jsonHeaders =>
      const {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode ~/ 100 == 2) {
      return (r.body.isEmpty) ? <String, dynamic>{} : jsonDecode(r.body);
    }
    throw Exception('GET $path -> ${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final r = await http
        .post(uri, headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode ~/ 100 == 2) {
      return (r.body.isEmpty) ? <String, dynamic>{} : jsonDecode(r.body);
    }
    throw Exception('POST $path -> ${r.statusCode} ${r.body}');
  }
}

final api = ApiClient();
