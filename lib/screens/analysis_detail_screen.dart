// lib/screens/analysis_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

Color riskColor(BuildContext context, double p) {
  final cs = Theme.of(context).colorScheme;
  if (p >= 0.70) return cs.error;        // high risk -> red
  if (p >= 0.45) return cs.tertiary;     // medium -> tertiary
  return cs.primary;                     // low -> brand color
}

String riskLabel(double p) {
  if (p >= 0.70) return 'High risk';
  if (p >= 0.45) return 'Moderate risk';
  return 'Low risk';
}

String fmtPct(double p) => '${(p * 100).toStringAsFixed(1)}%';

String fmtIso(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('yyyy-MM-dd • HH:mm').format(dt.toLocal());
}

String prettyLabel(String s) =>
    s.replaceAll('_', ' ')
     .split(' ')
     .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
     .join(' ');

// Small colored badge with decision + percentage
Widget riskBadge(BuildContext context, String decision, double prob) {
  final c = riskColor(context, prob);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.analytics_rounded, size: 16, color: c),
        const SizedBox(width: 6),
        Text(
          '${prettyLabel(decision)} • ${fmtPct(prob)}',
          style: TextStyle(color: c, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// Little rounded chip for joints/features (tappable)
Widget featureChip(
  BuildContext context, {
  required String text,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final child = Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    margin: const EdgeInsets.only(right: 8, bottom: 8),
    decoration: BoxDecoration(
      color: cs.surfaceVariant,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(prettyLabel(text), style: TextStyle(color: cs.onSurface)),
  );
  return onTap == null
      ? child
      : InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: child);
}

// Same base as in InjuryPredictionScreen
const String kApiBase = 'https://myswim-backend.onrender.com';

class AnalysisDetailScreen extends StatefulWidget {
  static const routeName = '/analysis-detail';
  const AnalysisDetailScreen({super.key});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  Future<void> _load(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Uses your new backend detail route
      final uri = Uri.parse('$kApiBase/api/results/$id');
      final resp = await http.get(uri).timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      setState(() => _data = jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as int;
    _load(id);
  }

  // ---- Helper: resolve angles from either top-level or meta.angles
  Map<String, dynamic>? get _angles {
    final top = _data?['angles'];
    if (top is Map) return top.cast<String, dynamic>();
    final meta = _data?['meta'];
    if (meta is Map && meta['angles'] is Map) {
      return (meta['angles'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  // ---- NEW: bottom sheet with angles by window for a specific joint
  void _showAnglesForJoint(String jointKey) {
    final angles = _angles;
    if (angles == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Angles not available for this result.')),
      );
      return;
    }

    // windows.frame_ranges: [[start,end], ...]
    final List<dynamic> rangesDyn =
        (angles['windows'] is Map && angles['windows']['frame_ranges'] is List)
            ? (angles['windows']['frame_ranges'] as List<dynamic>)
            : const [];

    final ranges = rangesDyn
        .map<List<int>>((e) => [(e[0] as num).toInt(), (e[1] as num).toInt()])
        .toList();

    // Two possible shapes for per_frame:
    // A) Map per joint -> List<double>
    //    angles['per_frame'] = { "left_knee_angle":[...], ... }
    // B) List per frame -> [lk, rk, ls, rs]
    //    angles['per_frame'] = [[...4 cols...], ...]
    final pf = angles['per_frame'];
    List<double> series;

    if (pf is Map) {
      final jointList = pf[jointKey];
      if (jointList is List) {
        series = jointList.map((n) => (n as num).toDouble()).toList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No series for $jointKey')),
        );
        return;
      }
    } else if (pf is List) {
      // column indexes for legacy shape
      const idxMap = {
        'left_knee_angle': 0,
        'right_knee_angle': 1,
        'left_shoulder_angle': 2,
        'right_shoulder_angle': 3,
      };
      final idx = idxMap[jointKey];
      if (idx == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown joint: $jointKey')),
        );
        return;
      }
      series = [];
      for (final row in pf) {
        if (row is List && row.length > idx) {
          series.add((row[idx] as num).toDouble());
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected angles format.')),
      );
      return;
    }

    // Compute mean per window
    final List<double> windowMeans = [];
    for (final r in ranges) {
      final start = r[0].clamp(0, series.length - 1);
      final end = r[1].clamp(0, series.length - 1);
      if (end < start) {
        windowMeans.add(0);
        continue;
      }
      double sum = 0;
      int n = 0;
      for (int f = start; f <= end; f++) {
        sum += series[f];
        n += 1;
      }
      windowMeans.add(n > 0 ? sum / n : 0);
    }

    final niceTitle = prettyLabel(jointKey);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$niceTitle • Angles by window',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              // Simple table
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text('Window',
                                style: TextStyle(
                                    color: cs.onSurface, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: Text('Avg angle (°)',
                                style: TextStyle(
                                    color: cs.onSurface, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    if (windowMeans.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('No windows found', style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                    for (int i = 0; i < windowMeans.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text('Window ${i + 1}',
                                  style: TextStyle(color: cs.onSurface)),
                            ),
                            Expanded(
                              child: Text(
                                windowMeans[i].toStringAsFixed(1),
                                style: TextStyle(color: cs.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: these are mean angles across frames inside each analysis window.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Failed to load: $_error'))
              : _data == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // --- Decision header with badge ---
                        if (_data!['prob'] != null && _data!['decision'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: riskBadge(
                              context,
                              (_data!['decision'] as String),
                              (_data!['prob'] as num).toDouble(),
                            ),
                          ),

                        // --- Summary card ---
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Summary', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                _kv('Filename', _data!['filename'] as String?),
                                _kv('Decision', prettyLabel(_data!['decision'] as String? ?? '')),
                                _kv(
                                  'Risk',
                                  (_data!['prob'] == null)
                                      ? '—'
                                      : fmtPct((_data!['prob'] as num).toDouble()),
                                ),
                                _kv(
                                  'Threshold',
                                  (_data!['th'] == null)
                                      ? '—'
                                      : (_data!['th'] as num).toStringAsFixed(3),
                                ),
                                _kv('Windows', _data!['window_cnt']?.toString()),
                                _kv('Created', fmtIso(_data!['created_at'] as String?)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // --- Most risky features (tappable chips) ---
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Most risky joints', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Wrap(
                                  children: (_data!['risky_features_overall'] as List<dynamic>? ?? [])
                                      .map((e) => featureChip(
                                            context,
                                            text: e.toString(),
                                            onTap: () => _showAnglesForJoint(e.toString()),
                                          ))
                                      .toList(),
                                ),
                                if (_data!['risky_features_overall'] == null ||
                                    (_data!['risky_features_overall'] as List).isEmpty)
                                  Text('No standout joints', style: TextStyle(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // --- Top features per window ---
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Top joints per window', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                ...List<Widget>.from(
                                  (_data!['per_window_top_features'] as List<dynamic>? ?? [])
                                      .asMap()
                                      .entries
                                      .map((e) {
                                    final idx = e.key;
                                    final list = (e.value as List<dynamic>? ?? [])
                                        .map((s) => prettyLabel(s.toString()))
                                        .join(', ');
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text('• Window ${idx + 1}: $list'),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _kv(String k, String? v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v ?? '—', style: TextStyle(color: cs.onSurface))),
        ],
      ),
    );
  }
}

