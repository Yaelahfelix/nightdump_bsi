import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'widgets/app_nav_bar.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _targets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db = await DatabaseHelper().db;
    final email = user['email']!;

    Future<List<Map<String, dynamic>>> q(String type) => db.rawQuery('''
      SELECT ni.id, ni.content, ni.done, ni.due_date, ni.note_id,
             n.created_at  AS note_date,
             n.summary     AS note_summary,
             n.raw_text    AS note_raw
      FROM note_items ni
      JOIN notes n ON ni.note_id = n.id
      WHERE n.user_email = ? AND ni.type = ?
      ORDER BY ni.done ASC,
               CASE WHEN ni.due_date IS NULL THEN 1 ELSE 0 END,
               ni.due_date ASC,
               n.created_at DESC
    ''', [email, type]);

    final todos     = await q('todo');
    final reminders = await q('reminder');
    final targets   = await q('target');

    if (mounted) {
      setState(() {
        _todos     = todos;
        _reminders = reminders;
        _targets   = targets;
        _loading   = false;
      });
    }
  }

  Future<void> _toggleDone(int id, int currentDone) async {
    final db = await DatabaseHelper().db;
    await db.update(
      'note_items',
      {'done': currentDone == 0 ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _load();
  }

  Future<void> _delete(int id) async {
    final db = await DatabaseHelper().db;
    await db.delete('note_items', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _setDueDate(int id, String? currentRaw) async {
    final now = DateTime.now();
    // Gunakan tanggal saat ini atau yang sudah ada sebagai initial
    DateTime initial = now;
    if (currentRaw != null && currentRaw != 'null') {
      initial = DateTime.tryParse(currentRaw.replaceFirst(' ', 'T'))
              ?.toLocal() ??
          now;
    }

    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD1B3FF),
        onPrimary: Color(0xFF13132B),
        surface: Color(0xFF1A1A3A),
      ),
    );

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal',
      cancelText: 'Batal',
      confirmText: 'Lanjut',
      builder: (ctx, child) => Theme(data: darkTheme, child: child!),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: initial.hour == 0 ? 8 : initial.hour,
          minute: initial.minute),
      helpText: 'Pilih Jam',
      cancelText: 'Batal',
      confirmText: 'Simpan',
      builder: (ctx, child) => Theme(data: darkTheme, child: child!),
    );
    if (time == null || !mounted) return;

    final dt     = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final dueStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final db = await DatabaseHelper().db;
    await db.update(
      'note_items',
      {'due_date': dueStr},
      where: 'id = ?',
      whereArgs: [id],
    );
    _load();
  }

  Future<void> _clearDueDate(int id) async {
    final db = await DatabaseHelper().db;
    await db.update('note_items', {'due_date': null},
        where: 'id = ?', whereArgs: [id]);
    _load();
  }

  int get _activeTodoCount => _todos.where((t) => t['done'] == 0).length;
  int get _activeReminderCount =>
      _reminders.where((r) => r['done'] == 0).length;
  int get _activeTargetCount =>
      _targets.where((t) => t['done'] == 0).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildTabBar(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFD1B3FF), strokeWidth: 2))
                      : TabBarView(
                          controller: _tab,
                          children: [
                            _buildList(_todos, 'todo'),
                            _buildList(_reminders, 'reminder'),
                            _buildList(_targets, 'target'),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 25,
            child: const AppNavBar(currentIndex: 4),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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

  // ── Tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: const Color(0xFF7B6FE8),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: 'TUGAS${_activeTodoCount > 0 ? ' ($_activeTodoCount)' : ''}'),
          Tab(
              text:
                  'PENGINGAT${_activeReminderCount > 0 ? ' ($_activeReminderCount)' : ''}'),
          Tab(
              text:
                  'TARGET${_activeTargetCount > 0 ? ' ($_activeTargetCount)' : ''}'),
        ],
      ),
    );
  }

  // ── List per tab ─────────────────────────────────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) return _buildEmptyTab(type);

    final active = items.where((i) => i['done'] == 0).toList();
    final done   = items.where((i) => i['done'] == 1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        ...active.map((i) => _buildItem(i, type)),
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('Selesai (${done.length})',
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ),
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.1))),
            ]),
          ),
          ...done.map((i) => _buildItem(i, type)),
        ],
      ],
    );
  }

  // ── Item card ────────────────────────────────────────────────────────────
  Widget _buildItem(Map<String, dynamic> item, String type) {
    final isDone      = item['done'] == 1;
    final id          = item['id'] as int;
    final content     = item['content'] as String;
    final noteDate    = _fmtDate(item['note_date'] as String? ?? '');
    final cfg         = _cfg[type] ?? _cfg['todo']!;
    final accentColor = cfg['color'] as Color;

    // Kutipan catatan asal — pakai summary AI, fallback ke raw text
    final summary  = (item['note_summary'] as String? ?? '').trim();
    final raw      = (item['note_raw']     as String? ?? '').trim();
    final excerpt  = (summary.isNotEmpty ? summary : raw).replaceAll('\n', ' ');
    final excerptTrimmed = excerpt.length > 100
        ? '${excerpt.substring(0, 100)}...'
        : excerpt;

    return Dismissible(
      key: ValueKey('item_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            SizedBox(height: 4),
            Text('Hapus', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
          ],
        ),
      ),
      onDismissed: (_) => _delete(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDone
              ? Colors.white.withValues(alpha: 0.02)
              : const Color(0xFF1A1A3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDone
                  ? Colors.white.withValues(alpha: 0.03)
                  : accentColor.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Baris utama: centang + isi + due ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tombol centang
                  GestureDetector(
                    onTap: () => _toggleDone(id, item['done'] as int),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? accentColor : Colors.transparent,
                        border: Border.all(
                          color: isDone ? accentColor : Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              size: 13, color: Color(0xFF13132B))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          style: TextStyle(
                            color: isDone
                                ? Colors.white24
                                : Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white24,
                          ),
                        ),
                        if (!isDone) ...[
                          const SizedBox(height: 8),
                          _buildDueChip(id, item['due_date'] as String?),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer: waktu + kutipan catatan ──────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDone ? 0.01 : 0.03),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waktu dicatat
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(width: 5),
                      Text(
                        'Dicatat $noteDate',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 11),
                      ),
                    ],
                  ),
                  // Kutipan catatan asal
                  if (excerptTrimmed.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.format_quote_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            excerptTrimmed,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                  alpha: isDone ? 0.12 : 0.22),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              height: 1.45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Due date chip ────────────────────────────────────────────────────────
  Widget _buildDueChip(int id, String? raw) {
    final label    = _fmtDue(raw);
    final color    = _dueColor(raw);
    final hasDue   = label != null;

    return GestureDetector(
      onTap: () => _setDueDate(id, raw),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: hasDue
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDue
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasDue ? Icons.schedule : Icons.add,
              size: 11,
              color: hasDue ? color : Colors.white24,
            ),
            const SizedBox(width: 4),
            Text(
              hasDue ? label : 'Atur waktu',
              style: TextStyle(
                color: hasDue ? color : Colors.white24,
                fontSize: 11,
                fontWeight:
                    hasDue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            // Tombol hapus tenggat
            if (hasDue) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _clearDueDate(id),
                child: Icon(
                  Icons.close,
                  size: 11,
                  color: color.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyTab(String type) {
    final cfg = _cfg[type] ?? _cfg['todo']!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg['icon'] as IconData,
              color: Colors.white12, size: 56),
          const SizedBox(height: 16),
          Text('Belum ada ${cfg['label'] as String}',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tulis catatan dan AI akan mengekstraknya',
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
              child: const Text('Catat Sekarang',
                  style: TextStyle(
                      color: Color(0xFF13132B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Label tanggal dari created_at (kapan catatan dibuat).
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
      return '$diff hari lalu';
    } catch (_) {
      return '';
    }
  }

  /// Label due date yang ramah — "Besok, 08:00", "Terlambat", dll.
  String? _fmtDue(String? raw) {
    if (raw == null || raw == 'null' || raw.isEmpty) return null;
    try {
      final dt    = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due   = DateTime(dt.year, dt.month, dt.day);
      final diff  = due.difference(today).inDays;
      final hasTime = dt.hour > 0 || dt.minute > 0;
      final hm    = hasTime
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
    if (raw == null || raw == 'null' || raw.isEmpty) return Colors.transparent;
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

  static const Map<String, Map<String, Object>> _cfg = {
    'todo': {
      'icon':  Icons.check_box_outlined,
      'color': Color(0xFFD1B3FF),
      'label': 'tugas',
    },
    'reminder': {
      'icon':  Icons.notifications_outlined,
      'color': Color(0xFFFFB347),
      'label': 'pengingat',
    },
    'target': {
      'icon':  Icons.flag_outlined,
      'color': Color(0xFF4ECCA3),
      'label': 'target',
    },
  };
}
