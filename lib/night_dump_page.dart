import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'widgets/app_nav_bar.dart';

class NightDumpPage extends StatefulWidget {
  const NightDumpPage({super.key});

  @override
  State<NightDumpPage> createState() => _NightDumpPageState();
}

class _NightDumpPageState extends State<NightDumpPage> {
  final _auth = AuthService();
  Map<String, String>? _user;
  Map<String, int> _stats = {'notes': 0, 'todos': 0, 'reminders': 0};
  List<Map<String, dynamic>> _recent = [];
  int _mood = -1; // indeks mood yang dipilih

  static const _moods = [
    {'icon': Icons.nights_stay_outlined, 'label': 'Tenang'},
    {'icon': Icons.cloud_outlined,       'label': 'Melamun'},
    {'icon': Icons.tornado,              'label': 'Gelisah'},
    {'icon': Icons.auto_awesome_outlined,'label': 'Terinspirasi'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUser(), _loadStats()]);
  }

  Future<void> _loadUser() async {
    final u = await _auth.getCurrentUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _loadStats() async {
    final user = await _auth.getCurrentUser();
    if (user == null) return;

    final db    = await DatabaseHelper().db;
    final email = user['email']!;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final notesRes = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM notes WHERE user_email=? AND created_at LIKE ?",
      [email, '$today%'],
    );
    final todosRes = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM note_items ni
      JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND ni.type='todo' AND ni.done=0
    ''', [email]);
    final remRes = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM note_items ni
      JOIN notes n ON ni.note_id=n.id
      WHERE n.user_email=? AND ni.type='reminder' AND ni.done=0
    ''', [email]);

    final recent = await db.rawQuery('''
      SELECT id, summary, raw_text, created_at FROM notes
      WHERE user_email=?
      ORDER BY created_at DESC LIMIT 3
    ''', [email]);

    if (!mounted) return;
    setState(() {
      _stats = {
        'notes':     notesRes.first['c'] as int,
        'todos':     todosRes.first['c'] as int,
        'reminders': remRes.first['c'] as int,
      };
      _recent =
          recent.map((r) => Map<String, dynamic>.from(r)).toList();
    });
  }

  Future<void> _saveMood(int idx) async {
    setState(() => _mood = idx);
    final db = await DatabaseHelper().db;
    await db.insert(
      'settings',
      {'key': 'last_mood', 'value': _moods[idx]['label'] as String},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5  && h < 12) return 'Selamat pagi';
    if (h >= 12 && h < 15) return 'Selamat siang';
    if (h >= 15 && h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String get _dateStr {
    final n = DateTime.now();
    const days   = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }

  String get _firstName =>
      (_user?['name'] ?? '').split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF13132B),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                color: const Color(0xFFD1B3FF),
                backgroundColor: const Color(0xFF1A1A3A),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildGreeting(),
                      const SizedBox(height: 20),
                      _buildStatsCard(),
                      const SizedBox(height: 20),
                      _buildMoodPicker(),
                      const SizedBox(height: 24),
                      _buildQuickNote(),
                      const SizedBox(height: 24),
                      if (_recent.isNotEmpty) ...[
                        _buildSectionTitle('Catatan Terbaru'),
                        const SizedBox(height: 12),
                        ..._recent.map(_buildRecentCard),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 25,
              child: const AppNavBar(currentIndex: 0),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.settings_outlined, color: Colors.white70),
        const Text('Night Dump',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        GestureDetector(
          onTap: _showProfile,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF7B6FE8),
            child: Text(
              _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'N',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── Greeting ──────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting${_firstName.isNotEmpty ? ', $_firstName' : ''}  🌙',
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(_dateStr,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }

  // ── Stats card ────────────────────────────────────────────────────────
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F1F45).withValues(alpha: 0.7),
            const Color(0xFF13132B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_stats['notes']}', 'Catatan\nHari Ini',
              Icons.notes, const Color(0xFFD1B3FF)),
          _divider(),
          _statItem('${_stats['todos']}', 'Tugas\nAktif',
              Icons.check_box_outlined, const Color(0xFF4ECCA3)),
          _divider(),
          _statItem('${_stats['reminders']}', 'Pengingat\nAktif',
              Icons.notifications_outlined, const Color(0xFFFFB347)),
        ],
      ),
    );
  }

  Widget _statItem(
      String val, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(val,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white38, fontSize: 11, height: 1.3)),
      ],
    );
  }

  Widget _divider() => Container(
      width: 1, height: 50,
      color: Colors.white.withValues(alpha: 0.08));

  // ── Mood picker ───────────────────────────────────────────────────────
  Widget _buildMoodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Perasaanmu Malam Ini'),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_moods.length, (i) {
            final selected = _mood == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _saveMood(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF7B6FE8).withValues(alpha: 0.3)
                        : const Color(0xFF1A1A3A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF7B6FE8)
                            : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _moods[i]['icon'] as IconData,
                        size: 20,
                        color: selected
                            ? const Color(0xFFD1B3FF)
                            : Colors.white38,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _moods[i]['label'] as String,
                        style: TextStyle(
                            color: selected
                                ? const Color(0xFFD1B3FF)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Quick note CTA ────────────────────────────────────────────────────
  Widget _buildQuickNote() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/notes'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFD1B3FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFFD1B3FF).withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Color(0xFFD1B3FF), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Apa yang ada di pikiranmu malam ini?',
                style: TextStyle(color: Color(0xFFD1B3FF), fontSize: 14),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFFD1B3FF), size: 14),
          ],
        ),
      ),
    );
  }

  // ── Recent notes ──────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2));
  }

  Widget _buildRecentCard(Map<String, dynamic> note) {
    final summary  = note['summary'] as String? ?? '';
    final rawText  = note['raw_text'] as String? ?? '';
    final display  = summary.isNotEmpty ? summary : rawText;
    final date     = _fmtDate(note['created_at'] as String? ?? '');

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/history'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161635).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 8),
            Text(display,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }

  // ── Profile bottom sheet ──────────────────────────────────────────────
  Future<void> _showProfile() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF7B6FE8),
              child: Text(
                _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'N',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(_user?['name'] ?? 'Pengguna',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_user?['email'] ?? '',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                await _auth.logout();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Keluar',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Date helper ───────────────────────────────────────────────────────
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
}
