import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'widgets/app_nav_bar.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fade;
  late Animation<double> _fadeAnim;

  int _period = 0; // 0=Minggu, 1=Bulan, 2=Tahun
  bool _loading = true;

  int    _noteCount     = 0;
  int    _itemCount     = 0;
  double _todoCompletion = 0;
  Map<String, int> _dist = {};
  List<String> _recentInsights = [];

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    _fade.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  String _fromDate() {
    final now = DateTime.now();
    final days = [7, 30, 365][_period];
    return now.subtract(Duration(days: days)).toIso8601String();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = await AuthService().getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db    = await DatabaseHelper().db;
    final email = user['email']!;
    final from  = _fromDate();

    final notesRes = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notes WHERE user_email=? AND created_at>=?',
      [email, from],
    );
    final itemsRes = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM note_items ni
      JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND n.created_at>=?
    ''', [email, from]);
    final distRes = await db.rawQuery('''
      SELECT ni.type, COUNT(*) AS cnt FROM note_items ni
      JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND n.created_at>=?
      GROUP BY ni.type
    ''', [email, from]);
    final totalTodos = (await db.rawQuery('''
      SELECT COUNT(*) AS c FROM note_items ni JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND ni.type='todo'
    ''', [email])).first['c'] as int;
    final doneTodos = (await db.rawQuery('''
      SELECT COUNT(*) AS c FROM note_items ni JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND ni.type='todo' AND ni.done=1
    ''', [email])).first['c'] as int;
    final insightRes = await db.rawQuery('''
      SELECT ni.content FROM note_items ni JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND ni.type='insight'
      ORDER BY n.created_at DESC LIMIT 4
    ''', [email]);

    final dist = <String, int>{};
    for (final r in distRes) {
      dist[r['type'] as String] = r['cnt'] as int;
    }

    if (!mounted) return;
    setState(() {
      _noteCount     = notesRes.first['c'] as int;
      _itemCount     = itemsRes.first['c'] as int;
      _todoCompletion =
          totalTodos > 0 ? doneTodos / totalTodos : 0;
      _dist          = dist;
      _recentInsights =
          insightRes.map((r) => r['content'] as String).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark()
          .copyWith(scaffoldBackgroundColor: const Color(0xFF13132B)),
      child: Scaffold(
        backgroundColor: const Color(0xFF13132B),
        body: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFD1B3FF),
                                  strokeWidth: 2))
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: const Color(0xFFD1B3FF),
                              backgroundColor: const Color(0xFF1A1A3A),
                              child: SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    20, 0, 20, 110),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 24),
                                    _buildHero(),
                                    const SizedBox(height: 20),
                                    if (_noteCount == 0)
                                      _buildEmpty()
                                    else ...[
                                      _buildSummaryCard(),
                                      const SizedBox(height: 16),
                                      _buildDistribusiCard(),
                                      const SizedBox(height: 16),
                                      _buildTodoRingCard(),
                                      if (_recentInsights.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildInsightsCard(),
                                      ],
                                      const SizedBox(height: 24),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 25,
              child: const AppNavBar(currentIndex: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
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
      ),
    );
  }

  // ── Hero + period selector ─────────────────────────────────────────────
  Widget _buildHero() {
    return Column(
      children: [
        const Text('Insightmu',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFFEAE9F5),
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.15)),
        const SizedBox(height: 8),
        Text('Pola dari pikiran malammu.',
            style: TextStyle(
                color: const Color(0xFFEAE9F5).withValues(alpha: 0.45),
                fontSize: 14)),
        const SizedBox(height: 20),
        _buildPeriodSelector(),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    const labels = ['Minggu', 'Bulan', 'Tahun'];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(3, (i) {
          final sel = _period == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _period = i);
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF7B6FE8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel
                            ? Colors.white
                            : const Color(0xFFEAE9F5)
                                .withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded,
              color: Colors.white.withValues(alpha: 0.1), size: 72),
          const SizedBox(height: 16),
          const Text('Belum ada data',
              style: TextStyle(color: Colors.white38, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Tulis beberapa catatan untuk melihat pola pikiranmu',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/notes'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
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
  }

  // ── Summary card ───────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    return _card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat('$_noteCount', 'Catatan',
              Icons.notes, const Color(0xFFD1B3FF)),
          Container(
              width: 1, height: 40,
              color: Colors.white.withValues(alpha: 0.08)),
          _miniStat('$_itemCount', 'Total Item',
              Icons.list_alt_rounded, const Color(0xFF7B9FE8)),
          Container(
              width: 1, height: 40,
              color: Colors.white.withValues(alpha: 0.08)),
          _miniStat(
              '${(_todoCompletion * 100).round()}%',
              'Tugas Selesai',
              Icons.task_alt_rounded,
              const Color(0xFF4ECCA3)),
        ],
      ),
    );
  }

  Widget _miniStat(
      String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(val,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  // ── Distribusi item ────────────────────────────────────────────────────
  Widget _buildDistribusiCard() {
    final total = _dist.values.fold(0, (a, b) => a + b);
    const types = ['todo', 'reminder', 'target', 'insight'];
    const labels = ['Tugas', 'Pengingat', 'Target', 'Insight'];
    const colors = [
      Color(0xFFD1B3FF),
      Color(0xFFFFB347),
      Color(0xFF4ECCA3),
      Color(0xFF7B9FE8),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DISTRIBUSI ITEM',
              style: TextStyle(
                  color: const Color(0xFFEAE9F5).withValues(alpha: 0.4),
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          ...List.generate(types.length, (i) {
            final count = _dist[types[i]] ?? 0;
            final ratio = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(labels[i],
                        style: TextStyle(
                            color: const Color(0xFFEAE9F5)
                                .withValues(alpha: 0.5),
                            fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: const Color(0xFF2A2A3C),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors[i]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 28,
                    child: Text('$count',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: colors[i],
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Ring: completion tugas ─────────────────────────────────────────────
  Widget _buildTodoRingCard() {
    return _card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Penyelesaian Tugas',
                  style: TextStyle(
                      color: Color(0xFFEAE9F5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text(
                  '${_dist['todo'] ?? 0} tugas total',
                  style: TextStyle(
                      color: const Color(0xFFEAE9F5)
                          .withValues(alpha: 0.4),
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _RingPainter(progress: _todoCompletion),
              child: Center(
                child: Text(
                  '${(_todoCompletion * 100).round()}%',
                  style: const TextStyle(
                      color: Color(0xFFEAE9F5),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _todoCompletion >= 0.8
                ? 'Luar biasa! Produktivitasmu tinggi 🎉'
                : _todoCompletion >= 0.4
                    ? 'Terus semangat, kamu di jalur yang benar!'
                    : 'Yuk mulai selesaikan tugas-tugasmu 💪',
            style: TextStyle(
                color: const Color(0xFFEAE9F5).withValues(alpha: 0.5),
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Insight terbaru ────────────────────────────────────────────────────
  Widget _buildInsightsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INSIGHT TERBARU',
              style: TextStyle(
                  color: const Color(0xFFEAE9F5).withValues(alpha: 0.4),
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ..._recentInsights.map((ins) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 10),
                      child: CircleAvatar(
                          radius: 2.5,
                          backgroundColor: Color(0xFF7B9FE8)),
                    ),
                    Expanded(
                      child: Text(ins,
                          style: const TextStyle(
                              color: Color(0xFFCCCAE8),
                              fontSize: 13,
                              height: 1.5,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Shared card wrapper ────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

// ── Ring painter ───────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    const sw = 8.0;

    canvas.drawCircle(c, r,
        Paint()
          ..color = const Color(0xFF2A2A3C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi * progress, false,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [Color(0xFF7B6FE8), Color(0xFF4ECCA3)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress;
}
