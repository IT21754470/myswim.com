// lib/screens/swimmer_dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/swim_history_store.dart';

/// ===== Colors & accents by distance =====
class BrandColors {
  static const headline = Color(0xFF0F172A);

  static const tile1Start = Color(0xFF00B4D8);
  static const tile1End   = Color(0xFF0077B6);
  static const tile2Start = Color(0xFFFF7A59);
  static const tile2End   = Color(0xFFF4A261);
  static const tile3Start = Color(0xFF6D28D9);
  static const tile3End   = Color(0xFF8B5CF6);
  static const tile4Start = Color(0xFF14B8A6);
  static const tile4End   = Color(0xFF0EA5E9);
}

List<Color> _accentFor(String distance) {
  switch (distance) {
    case '50m':  return const [BrandColors.tile1Start, BrandColors.tile1End];
    case '100m': return const [BrandColors.tile2Start, BrandColors.tile2End];
    case '200m': return const [BrandColors.tile3Start, BrandColors.tile3End];
    case '400m': return const [BrandColors.tile4Start, BrandColors.tile4End];
    default:     return const [BrandColors.tile1Start, BrandColors.tile1End];
  }
}

class SwimmerDashboardScreen extends StatefulWidget {
  const SwimmerDashboardScreen({super.key});
  @override
  State<SwimmerDashboardScreen> createState() => _SwimmerDashboardScreenState();
}

class _SwimmerDashboardScreenState extends State<SwimmerDashboardScreen> {
  final _store = SwimHistoryStore();
  Timer? _ticker; // live refresh for countdowns

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {}); // keep countdown fresh
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // Parse "mm:ss.xx" or seconds -> total seconds
  double _timeToSeconds(String? t) {
    if (t == null || t.trim().isEmpty) return double.nan;
    final s = t.trim();
    final i = s.indexOf(':');
    try {
      if (i >= 0) {
        final mm = int.parse(s.substring(0, i));
        final ss = double.parse(s.substring(i + 1));
        return mm * 60 + ss;
      }
      return double.parse(s);
    } catch (_) {
      return double.nan;
    }
  }

  // Try to find a baseline for a prediction row if it's missing/invalid.
  // Priority:
  // 1) Use s.bestTimeText if it parses
  // 2) Latest non-prediction for same swimmerId/name + distance + stroke
  // 3) Latest non-prediction for same distance + stroke (any swimmer)
  double _resolveBaselineSeconds(TrainingSession s) {
    final fromSelf = _timeToSeconds(s.bestTimeText);
    if (!fromSelf.isNaN && fromSelf > 0) return fromSelf;

    TrainingSession? candidate;

    bool sameEvent(TrainingSession t) =>
        !t.isPrediction &&
        t.distance == s.distance &&
        t.stroke == s.stroke;

    bool sameSwimmer(TrainingSession t) {
      final idOk   = (s.swimmerId?.isNotEmpty == true)   && s.swimmerId == t.swimmerId;
      final nameOk = (s.swimmerName?.isNotEmpty == true) && s.swimmerName == t.swimmerName;
      return idOk || nameOk;
    }

    // (2) same swimmer + same event
    for (final t in _store.items) {
      if (sameEvent(t) && sameSwimmer(t) && (t.bestTimeText?.isNotEmpty ?? false)) {
        if (candidate == null || t.sessionDate.isAfter(candidate!.sessionDate)) {
          candidate = t;
        }
      }
    }

    // (3) same event only
    candidate ??= _store.items
        .where((t) => sameEvent(t) && (t.bestTimeText?.isNotEmpty ?? false))
        .fold<TrainingSession?>(null, (prev, t) {
      if (prev == null || t.sessionDate.isAfter(prev.sessionDate)) return t;
      return prev;
    });

    return _timeToSeconds(candidate?.bestTimeText);
  }

  // Friendly time-to-go/ago string with d/h/m resolution
  String _timeLeftText(DateTime target) {
    final now = DateTime.now();
    final diff = target.difference(now);
    if (diff.inSeconds.abs() < 60) return 'Now';

    if (diff.isNegative) {
      final ad = diff.abs();
      if (ad.inDays >= 1) return '${ad.inDays}d ago';
      if (ad.inHours >= 1) return '${ad.inHours}h ago';
      return '${ad.inMinutes}m ago';
    } else {
      if (diff.inDays >= 1) return '${diff.inDays}d to go';
      if (diff.inHours >= 1) return '${diff.inHours}h to go';
      return '${diff.inMinutes}m to go';
    }
  }

  // Parse confidence like "±0.4s" -> 0.4
  double _confidenceBandSeconds(String? conf) {
    if (conf == null) return double.nan;
    final m = RegExp(r'±\s*([\d.]+)s').firstMatch(conf);
    if (m == null) return double.nan;
    return double.tryParse(m.group(1)!) ?? double.nan;
  }

  // Map band to label/color
  ({String label, Color color}) _accuracyFromBand(double band) {
    if (band.isNaN) return (label: 'Unknown', color: Colors.grey);
    if (band <= 0.5) return (label: 'High', color: const Color(0xFF16A34A));       // green
    if (band <= 0.7) return (label: 'Med-High', color: const Color(0xFF22C55E));   // green-ish
    if (band <= 1.0) return (label: 'Medium', color: const Color(0xFFF59E0B));     // amber
    return (label: 'Low', color: const Color(0xFFEF4444));                          // red
  }

  String _displayNameFor(TrainingSession s) {
    final id = s.swimmerId?.trim();
    final name = s.swimmerName?.trim();
    if ((name?.isNotEmpty ?? false) && (id?.isNotEmpty ?? false)) {
      return '$name (#$id)';
    }
    if (name?.isNotEmpty ?? false) return name!;
    if (id?.isNotEmpty ?? false) return 'ID ${id!}';
    return 'Unassigned';
  }

  String _initials(String? text) {
    final s = (text ?? '').trim();
    if (s.isEmpty) return '—';
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final p = parts.first;
      if (p.startsWith('ID ')) {
        final id = p.replaceFirst('ID ', '');
        return id.isNotEmpty ? id.characters.first.toUpperCase() : 'I';
      }
      return p.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // FUTURE predictions (incl. today) for list
    final upcoming = _store.items.where((r) =>
        r.isPrediction &&
        (DateTime(r.sessionDate.year, r.sessionDate.month, r.sessionDate.day)
                .isAfter(today) ||
            DateUtils.isSameDay(r.sessionDate, today)));

    // Best (fastest) per swimmer+date+event
    final Map<String, TrainingSession> bestByKey = {};
    for (final s in upcoming) {
      final key =
          '${s.swimmerId ?? "-"}|${s.swimmerName ?? "-"}|${DateFormat('yyyy-MM-dd').format(s.sessionDate)}|${s.distance}|${s.stroke}';
      final cur = bestByKey[key];
      if (cur == null ||
          _timeToSeconds(s.predictedTime) < _timeToSeconds(cur.predictedTime)) {
        bestByKey[key] = s;
      }
    }
    final rows = bestByKey.values.toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    // ===== TODAY OVERVIEW (aggregated accuracy per swimmer) =====
    final todayPreds = _store.items.where(
      (r) => r.isPrediction && DateUtils.isSameDay(r.sessionDate, today),
    );

    // Group by swimmer (id|name), compute avg band
    final Map<String, _Agg> aggBySwimmer = {};
    for (final p in todayPreds) {
      final key = '${p.swimmerId ?? ""}|${p.swimmerName ?? ""}';
      final dispName = _displayNameFor(p);
      final band = _confidenceBandSeconds(p.confidence);
      aggBySwimmer.putIfAbsent(key, () => _Agg(name: dispName));
      if (!band.isNaN) {
        aggBySwimmer[key]!.bands.add(band);
      } else {
        aggBySwimmer[key]!.unknownCount++;
      }
      aggBySwimmer[key]!.totalCount++;
    }
    final swimmerAgg = aggBySwimmer.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Team average band for today
    final allBands = swimmerAgg.expand((a) => a.bands).toList();
    final teamAvgBand = allBands.isEmpty
        ? double.nan
        : allBands.reduce((a, b) => a + b) / allBands.length;
    final teamAcc = _accuracyFromBand(teamAvgBand);

    // How many today
    final swimmersToday = swimmerAgg.length;
    final predictionsToday = todayPreds.length;
    final eventsToday = todayPreds
        .map((e) => '${e.distance}|${e.stroke}')
        .toSet()
        .length;

    // Choose accent for header
    final headerAccent = rows.isNotEmpty
        ? _accentFor(rows.first.distance)
        : const [BrandColors.tile1Start, BrandColors.tile1End];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swimmer Dashboard'),
        flexibleSpace: rows.isNotEmpty
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _accentFor(rows.first.distance),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              )
            : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: rows.isEmpty
          ? _EmptyState(onClear: _store.clear)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: rows.length + 1, // + header
              itemBuilder: (context, index) {
                // ===== Header with Today Overview =====
                if (index == 0) {
                  if (predictionsToday == 0) {
                    return const SizedBox.shrink();
                  }
                  final avgText = teamAvgBand.isNaN
                      ? '—'
                      : '±${teamAvgBand.toStringAsFixed(1)}s';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TodayOverviewHeader(
                        accent: headerAccent,
                        avgText: avgText,
                        accColor: teamAcc.color,
                        accLabel: teamAcc.label,
                        swimmers: swimmersToday,
                        events: eventsToday,
                        predictions: predictionsToday,
                      ),
                      const SizedBox(height: 12),
                      _TodayGrid(
                        items: swimmerAgg,
                        accuracyFromBand: _accuracyFromBand,
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                // ===== Regular upcoming card rows =====
                final s = rows[index - 1];
                final accent = _accentFor(s.distance);

                final secsPred = _timeToSeconds(s.predictedTime);
                final secsBaseResolved = _resolveBaselineSeconds(s);

                final hasBaseline = !secsBaseResolved.isNaN;
                final delta = (hasBaseline && !secsPred.isNaN)
                    ? secsPred - secsBaseResolved
                    : double.nan;
                final pct =
                    (!delta.isNaN && secsBaseResolved > 0) ? (delta / secsBaseResolved) * 100 : double.nan;

                final status = _progressStatus(delta);

                // Fallback identity from a matching non-prediction session (same date & event).
                TrainingSession? fallback;
                for (final t in _store.items) {
                  if (!t.isPrediction &&
                      DateUtils.isSameDay(t.sessionDate, s.sessionDate) &&
                      t.distance == s.distance &&
                      t.stroke == s.stroke) {
                    fallback = t;
                    break;
                  }
                }
                final displaySwimmerId   = s.swimmerId   ?? fallback?.swimmerId;
                final displaySwimmerName = s.swimmerName ?? fallback?.swimmerName;

                // Accuracy for chip (per-card)
                final band   = _confidenceBandSeconds(s.confidence);
                final acc    = _accuracyFromBand(band);
                final accStr = s.confidence == null ? acc.label : '${acc.label} (${s.confidence})';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UpcomingCard(
                    s: s,
                    accent: accent,
                    status: status,
                    delta: delta,
                    pct: pct,
                    displaySwimmerId: displaySwimmerId,
                    displaySwimmerName: displaySwimmerName,
                    timeLeftText: _timeLeftText(s.sessionDate),
                    accuracyLabel: accStr,
                    accuracyColor: acc.color,
                  ),
                );
              },
            ),
    );
  }

  /// Decide status color/icon/label from delta seconds (predicted - best).
  _Status _progressStatus(double deltaSeconds) {
    if (deltaSeconds.isNaN || deltaSeconds.isInfinite) {
      return const _Status(
        label: 'No baseline',
        color: Color(0xFFF59E0B), // amber
        icon: Icons.thumbs_up_down_rounded,
      );
    }
    if (deltaSeconds <= -0.30) {
      return const _Status(
        label: 'On track',
        color: Color(0xFF22C55E),
        icon: Icons.thumb_up_rounded,
      );
    }
    if (deltaSeconds > 0.50) {
      return const _Status(
        label: 'Needs work',
        color: Color(0xFFEF4444),
        icon: Icons.thumb_down_rounded,
      );
    }
    return const _Status(
      label: 'Borderline',
      color: Color(0xFFF59E0B),
      icon: Icons.thumbs_up_down_rounded,
    );
  }
}

/// ===== Today Overview widgets =====
class _Agg {
  _Agg({required this.name});
  final String name;
  final List<double> bands = [];
  int totalCount = 0;
  int unknownCount = 0;

  double get avgBand => bands.isEmpty
      ? double.nan
      : bands.reduce((a, b) => a + b) / bands.length;
}

class _TodayOverviewHeader extends StatelessWidget {
  final List<Color> accent;
  final String avgText;
  final Color accColor;
  final String accLabel;
  final int swimmers;
  final int events;
  final int predictions;
  const _TodayOverviewHeader({
    super.key,
    required this.accent,
    required this.avgText,
    required this.accColor,
    required this.accLabel,
    required this.swimmers,
    required this.events,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEE, dd MMM').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [accent.first.withOpacity(.12), accent.last.withOpacity(.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.last.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: accent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.insights_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Today performance accuracy',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Chip(
              label: Text(todayStr),
              backgroundColor: Colors.white,
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Avg $avgText',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accColor.withOpacity(.35)),
                ),
                child: Text(
                  accLabel,
                  style: TextStyle(
                    color: accColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Wrap(spacing: 6, children: [
                _miniStat(Icons.groups_2_rounded, '$swimmers swimmers'),
                _miniStat(Icons.flag_rounded, '$events events'),
                _miniStat(Icons.timeline_rounded, '$predictions predictions'),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
    );
  }
}

class _TodayGrid extends StatelessWidget {
  final List<_Agg> items;
  final ({String label, Color color}) Function(double band) accuracyFromBand;
  const _TodayGrid({
    super.key,
    required this.items,
    required this.accuracyFromBand,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, i) {
        final a = items[i];
        final acc = accuracyFromBand(a.avgBand);
        final bandText = a.avgBand.isNaN ? '—' : '±${a.avgBand.toStringAsFixed(1)}s';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: acc.color.withOpacity(.25)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: acc.color.withOpacity(.12),
                child: Text(
                  _initials(a.name),
                  style: TextStyle(
                    color: acc.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '$bandText · ${acc.label}',
                      style: TextStyle(
                        color: acc.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String? text) {
    final s = (text ?? '').trim();
    if (s.isEmpty) return '—';
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }
}

/// ===== Upcoming card (kept, with small tweaks) =====
class _UpcomingCard extends StatelessWidget {
  final TrainingSession s;
  final List<Color> accent;
  final _Status status;
  final double delta; // predicted - best (seconds)
  final double pct;   // % vs baseline
  final String? displaySwimmerId;   // resolved
  final String? displaySwimmerName; // resolved
  final String timeLeftText;        // friendly time text
  final String accuracyLabel;       // "High (±0.4s)"
  final Color accuracyColor;

  const _UpcomingCard({
    required this.s,
    required this.accent,
    required this.status,
    required this.delta,
    required this.pct,
    required this.timeLeftText,
    required this.accuracyLabel,
    required this.accuracyColor,
    this.displaySwimmerId,
    this.displaySwimmerName,
    super.key,
  });

  String _deltaText() {
    if (delta.isNaN || delta.isInfinite) return '—';
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(2)}s';
  }

  String _pctText() {
    if (pct.isNaN || pct.isInfinite) return '';
    final sign = pct > 0 ? '+' : '';
    return '  ($sign${pct.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, dd MMM').format(s.sessionDate);
    final id   = (displaySwimmerId  ?? s.swimmerId)   ?? '—';
    final name = (displaySwimmerName ?? s.swimmerName) ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
        border: Border.all(color: accent.last.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top ribbon
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: accent),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: event + date + countdown
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: accent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${s.distance} • ${s.stroke}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    Wrap(spacing: 8, children: [
                      Chip(
                        backgroundColor: accent.first.withOpacity(0.12),
                        label: Text(date),
                      ),
                      Chip(
                        avatar: const Icon(Icons.hourglass_bottom_rounded,
                            size: 16, color: Colors.teal),
                        label: Text(timeLeftText),
                        backgroundColor: Colors.teal.withOpacity(.08),
                        labelStyle: const TextStyle(color: Colors.teal),
                      ),
                    ]),
                  ],
                ),

                const SizedBox(height: 10),

                // “table” row with swimmer + predicted + like/dislike
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6EEF6)),
                  ),
                  child: Row(
                    children: [
                      _cell('Swimmer ID', id,   flex: 2),
                      _cell('Swimmer Name', name, flex: 3),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(status.icon, color: status.color, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  s.predictedTime ?? '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: status.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Δ ${_deltaText()}${_pctText()}',
                              style: TextStyle(
                                color: status.color.withOpacity(.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Info pills
                Wrap(
                  spacing: 8,
                  runSpacing: -6,
                  children: [
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: status.color.withOpacity(.15),
                        child: Icon(status.icon, color: status.color, size: 16),
                      ),
                      label: Text(status.label),
                      backgroundColor: status.color.withOpacity(.10),
                      labelStyle: TextStyle(color: status.color),
                      side: BorderSide(color: status.color.withOpacity(.35)),
                    ),
                    if ((s.competition ?? '').isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.emoji_events_outlined,
                            size: 16, color: Colors.orange),
                        label: Text(s.competition!),
                        backgroundColor: Colors.orange.withOpacity(.10),
                      ),
                    Chip(
                      avatar: const Icon(Icons.insights_rounded,
                          size: 16, color: Colors.indigo),
                      label: Text('Accuracy: $accuracyLabel'),
                      backgroundColor: accuracyColor.withOpacity(.10),
                      labelStyle: TextStyle(color: accuracyColor),
                      side: BorderSide(color: accuracyColor.withOpacity(.35)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Status {
  final String label;
  final Color color;
  final IconData icon;
  const _Status({required this.label, required this.color, required this.icon});
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('No upcoming predictions yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Save a prediction with a future race date to see it here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear History'),
            ),
          ],
        ),
      ),
    );
  }
}
