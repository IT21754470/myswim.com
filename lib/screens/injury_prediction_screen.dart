// lib/screens/injury_prediction_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

  List<AnalysisSummary> _recent = [];
  bool _recentLoading = false;
  String? _recentError;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

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

Future<void> _loadRecent() async {
  setState(() {
    _recentLoading = true;
    _recentError = null;
  });
  try {
    final uri = Uri.parse('$kApiBase/db/recent?limit=20');
    final resp = await http.get(uri).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final List<dynamic> arr = jsonDecode(resp.body) as List<dynamic>;
    final items = arr
        .map((e) => AnalysisSummary.fromJson(e as Map<String, dynamic>))
        .toList();

    // (Backend should already be newest-first; keep a defensive sort)
    items.sort((a, b) =>
        (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    setState(() => _recent = items);
  } catch (e) {
    setState(() => _recentError = e.toString());
  } finally {
    if (mounted) setState(() => _recentLoading = false);
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
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Tips for best accuracy', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  const _TipRow('Capture full body in frame.'),
                  const _TipRow('Good lighting; avoid heavy reflections.'),
                  const _TipRow('Keep one swimmer in frame'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
Card(
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history),
            const SizedBox(width: 8),
            Text('Recent analyses', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _recentLoading ? null : _loadRecent,
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_recentLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_recentError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load: $_recentError'),
          )
        else if (_recent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No results yet. Analyze a video to see it here.'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recent.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = _recent[i];
              return _RecentResultTile(
                item: item,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/analysis-detail',
                    arguments: item.id,
                  );
                },
              );
            },
          ),
      ],
    ),
  ),
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

class _TipRow extends StatelessWidget {
  final String tip;
  const _TipRow(this.tip);
 
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              color: cs.onSurface, // ← FORCE VISIBLE TEXT COLOR
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class AnalysisSummary {
  final int id;
  final DateTime? createdAt;
  final double? prob;
  final String? decision;
  final String? topJoint;

  AnalysisSummary({
    required this.id,
    this.createdAt,
    this.prob,
    this.decision,
    this.topJoint,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> j) {
    return AnalysisSummary(
      id: j['id'] as int,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      prob: (j['prob'] == null) ? null : (j['prob'] as num).toDouble(),
      decision: j['decision'] as String?,
      topJoint: j['top_joint'] as String?,
    );
  }
}

class _RecentResultTile extends StatelessWidget {
  final AnalysisSummary item;
  final VoidCallback onTap;
  const _RecentResultTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = (item.createdAt != null)
        ? DateFormat('y-MM-dd • HH:mm').format(item.createdAt!.toLocal())
        : '—';
    final pct = (item.prob != null) ? '${(item.prob! * 100).toStringAsFixed(1)}%' : '—';
    final joint = item.topJoint ?? '—';

    return ListTile(
      title: Text(dt),
      subtitle: Text('Risk: $pct   •   Top joint: $joint'),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}




