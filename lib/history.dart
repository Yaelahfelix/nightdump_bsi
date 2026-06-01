import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'widgets/app_nav_bar.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await AuthService().getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db    = await DatabaseHelper().db;
    final notes = await db.query(
      'notes',
      where: 'user_email = ?',
      whereArgs: [user['email']],
      orderBy: 'created_at DESC',
      limit: 30,
    );
    final enriched = <Map<String, dynamic>>[];
    for (final n in notes) {
      final items = await db.query(
        'note_items', where: 'note_id = ?', whereArgs: [n['id']],
      );
      enriched.add({...n, 'items': items});
    }
    if (mounted) setState(() { _notes = enriched; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFD1B3FF),
              backgroundColor: const Color(0xFF1A1A3A),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFD1B3FF), strokeWidth: 2)),
                    )
                  else if (_notes.isEmpty)
                    _empty()
                  else ...[
                    _savedBanner(),
                    const SizedBox(height: 20),
                    ..._notes.map(_noteCard),
                    _sleepBtn(),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 25,
            child: const AppNavBar(currentIndex: 3),
          ),
        ],
      ),
    );
  }

  Widget _header() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(Icons.settings_outlined, color: Colors.white70),
          Text('Night Dump',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF7B6FE8),
            child: Text('N',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      );

  Widget _savedBanner() => Column(
        children: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD1B3FF).withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 10)
                  ]),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFFD1B3FF), size: 56),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Catatan tersimpan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text(
              'AI telah memahami dan mengorganisir pikiranmu.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.white54, height: 1.5)),
        ],
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.nights_stay_outlined,
                color: Colors.white12, size: 72),
            const SizedBox(height: 20),
            const Text('Belum ada catatan',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text('Mulai tulis catatanmu malam ini',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/notes'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1B3FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text('Mulai Catat',
                    style: TextStyle(
                        color: Color(0xFF13132B),
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

  Widget _noteCard(Map<String, dynamic> note) {
    final items   = note['items'] as List;
    final summary = note['summary'] as String? ?? '';
    final raw     = note['raw_text'] as String? ?? '';
    final date    = _fmtDate(note['created_at'] as String? ?? '');

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      final t = i['type'] as String? ?? 'insight';
      grouped.putIfAbsent(t, () => []).add(Map<String, dynamic>.from(i as Map));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161635).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Icon(Icons.notes, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.isNotEmpty ? summary : raw,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5),
            maxLines: summary.isNotEmpty ? null : 3,
            overflow: summary.isNotEmpty ? null : TextOverflow.ellipsis,
          ),
          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 16),
            ...grouped.entries.map((e) => _group(e.key, e.value)),
          ],
        ],
      ),
    );
  }

  Widget _group(String type, List<Map<String, dynamic>> items) {
    final cfg = _typeCfg[type] ?? _typeCfg['insight']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cfg['icon'] as IconData,
                  color: cfg['color'] as Color, size: 13),
              const SizedBox(width: 6),
              Text(cfg['label'] as String,
                  style: TextStyle(
                      color: cfg['color'] as Color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(width: 6),
              Text('${items.length} item',
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final content = item['content'] as String? ?? '';
            final dueLabel = _fmtDue(item['due_date'] as String?);
            final dueColor = _dueColor(item['due_date'] as String?);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 10),
                    child: CircleAvatar(
                        radius: 2,
                        backgroundColor: cfg['color'] as Color),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(content,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4)),
                        if (dueLabel != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 10, color: dueColor),
                              const SizedBox(width: 3),
                              Text(dueLabel,
                                  style: TextStyle(
                                      color: dueColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String? _fmtDue(String? raw) {
    if (raw == null || raw == 'null' || raw.isEmpty) return null;
    try {
      final dt    = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due   = DateTime(dt.year, dt.month, dt.day);
      final diff  = due.difference(today).inDays;
      final hm    = (dt.hour > 0 || dt.minute > 0)
          ? ', ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';
      if (diff < 0) return 'Terlambat$hm';
      if (diff == 0) return 'Hari ini$hm';
      if (diff == 1) return 'Besok$hm';
      if (diff == 2) return 'Lusa$hm';
      if (diff <= 7)  return '$diff hari lagi$hm';
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      return '${dt.day} ${months[dt.month - 1]}$hm';
    } catch (_) {
      return raw;
    }
  }

  Color _dueColor(String? raw) {
    if (raw == null || raw == 'null' || raw.isEmpty) {
      return Colors.transparent;
    }
    try {
      final dt    = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due   = DateTime(dt.year, dt.month, dt.day);
      final diff  = due.difference(today).inDays;
      if (diff < 0) return Colors.redAccent;
      if (diff == 0) return const Color(0xFFFFB347);
      return Colors.white38;
    } catch (_) {
      return Colors.white38;
    }
  }

  Widget _sleepBtn() => Center(
        child: GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            decoration: BoxDecoration(
                color: const Color(0xFFD1B3FF),
                borderRadius: BorderRadius.circular(30)),
            child: const Text('TIDUR SEKARANG',
                style: TextStyle(
                    color: Color(0xFF13132B),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12)),
          ),
        ),
      );

  String _fmtDate(String iso) {
    try {
      final dt    = DateTime.parse(iso).toLocal();
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day   = DateTime(dt.year, dt.month, dt.day);
      final diff  = today.difference(day).inDays;
      final hm    =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return 'Hari ini, $hm';
      if (diff == 1) return 'Kemarin, $hm';
      return '$diff hari lalu, $hm';
    } catch (_) {
      return '';
    }
  }

  static const Map<String, Map<String, Object>> _typeCfg = {
    'todo':     {'icon': Icons.check_box_outlined,       'color': Color(0xFFD1B3FF), 'label': 'TUGAS'},
    'reminder': {'icon': Icons.notifications_outlined,   'color': Color(0xFFFFB347), 'label': 'PENGINGAT'},
    'target':   {'icon': Icons.flag_outlined,            'color': Color(0xFF4ECCA3), 'label': 'TARGET'},
    'insight':  {'icon': Icons.lightbulb_outline,        'color': Color(0xFF7B9FE8), 'label': 'INSIGHT'},
  };
}
