// lib/screens/injury_prediction_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

class InjuryPredictionScreen extends StatefulWidget {
  static const routeName = '/injury-prediction';
  const InjuryPredictionScreen({super.key});

  @override
  State<InjuryPredictionScreen> createState() => _InjuryPredictionScreenState();
}

class _InjuryPredictionScreenState extends State<InjuryPredictionScreen> {
  // ---- CHANGE ME IF YOU USE A DIFFERENT DOMAIN ----
  static const String kApiBase = 'https://myswim-backend.onrender.com';

  VideoPlayerController? _controller;
  File? _videoFile;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.video);
      if (res == null || res.files.single.path == null) return;

      final file = File(res.files.single.path!);
      await _controller?.dispose();
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      setState(() {
        _videoFile = file;
        _controller = controller;
      });

      _controller?.setLooping(true);
      _controller?.pause();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
    }
  }

  Future<void> _analyzeVideo() async {
  if (_videoFile == null) return;
  setState(() => _isAnalyzing = true);

  try {
    final uri = Uri.parse('$kApiBase/api/analyze');                  // <— POST here
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', _videoFile!.path));

    // Longer timeout because video analysis can take time on Render
    final streamed = await req.send().timeout(const Duration(seconds: 180));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
    }

    final Map<String, dynamic> json = jsonDecode(resp.body);
    // Navigate to results screen with the JSON payload
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/analysis-results',
      arguments: json, // AnalysisResultsScreen will read this Map
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Analyze failed: $e')),
    );
  } finally {
    if (mounted) setState(() => _isAnalyzing = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Injury Prediction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
              child: _controller == null
                  ? _EmptyPreview(icon: Icons.ondemand_video, label: 'No video selected')
                  : Stack(
                      children: [
                        VideoPlayer(_controller!),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(_controller!.value.isPlaying ? 'Pause' : 'Play'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAnalyzing ? null : _pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Select video'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (_videoFile == null || _isAnalyzing) ? null : _analyzeVideo,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.analytics),
                  label: Text(_isAnalyzing ? 'Analyzing…' : 'Analyze video'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Note: requires Internet permission. Make sure android/app/src/main/AndroidManifest.xml includes '
            '<uses-permission android:name="android.permission.INTERNET"/>',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyPreview({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}


