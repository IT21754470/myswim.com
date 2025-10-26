import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

const String apiBaseUrl = 'https://swimapi.onrender.com'; // your backend URL

Future<Position> getCurrentPosition() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) throw Exception('Location services are disabled');

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw Exception('Location permission denied');
  }

  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
}

Future<Map<String, dynamic>> fetchEnv(double lat, double lon) async {
  final uri = Uri.parse('$apiBaseUrl/api/env?lat=$lat&lon=$lon');
  final res = await http.get(uri);
  if (res.statusCode != 200) throw Exception('Env fetch failed: ${res.body}');
  return jsonDecode(res.body) as Map<String, dynamic>;
}