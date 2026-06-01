import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
import 'services/ai_service.dart';
import 'widgets/app_nav_bar.dart';

class Notes extends StatefulWidget {
  const Notes({super.key});

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  final _ctrl   = TextEditingController();
  final _speech = SpeechToText();

  bool _processing      = false;
  bool _isListening     = false;
  bool _speechAvailable = false;
  String _baseText      = ''; // teks sebelum sesi mic saat ini

  // Loading copy cycling
  int    _loadingIdx   = 0;
  Timer? _loadingTimer;

  static const _loadingCopy = [
    'Malam ini,\nbanyak yang ingin\ndisampaikan...',
    'Setiap kata\npunya\ntempatnya sendiri...',
    'Memilah antara\nmimpi dan\naksi nyata...',
    'Merajut pikiran\nmenjadi\nrencana nyata...',
    'Menata semua\nyang penting\nuntukmu...',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _loadingTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  // ── Speech init ──────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (['done', 'notListening'].contains(status)) {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mikrofon tidak tersedia di perangkat ini'),
          backgroundColor: Color(0xFF1A1A3A),
        ),
      );
      return;
    }

    // Simpan teks saat ini sebagai base sebelum rekam
    _baseText = _ctrl.text.trim();
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        final combined =
            _baseText.isEmpty ? words : '$_baseText\n$words';
        setState(() {
          _ctrl.text = combined;
          _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: combined.length),
          );
        });
      },
      listenFor: const Duration(minutes: 5),
      pauseFor:  const Duration(seconds: 3),
      localeId: 'id_ID',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  // ── Loading copy cycle ───────────────────────────────────────────────────
  void _startCycle() {
    _loadingIdx  = 0;
    _loadingTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) {
        if (mounted) {
          setState(() =>
              _loadingIdx = (_loadingIdx + 1) % _loadingCopy.length);
        }
      },
    );
  }

  void _stopCycle() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _letGo() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tulis atau ucapkan catatanmu dulu ya...'),
          backgroundColor: Color(0xFF1A1A3A),
        ),
      );
      return;
    }

    if (_isListening) await _speech.stop();

    setState(() => _processing = true);
    _startCycle();

    try {
      final user  = await AuthService().getCurrentUser();
      final email = user?['email'] ?? '';

      final db       = await DatabaseHelper().db;
      final moodRows = await db.query(
          'settings', where: "key = 'last_mood'", limit: 1);
      final mood = moodRows.isNotEmpty
          ? moodRows.first['value'] as String?
          : null;

      final aiResult = await AiService().analyzeNote(text, mood: mood);

      if (aiResult == null) {
        _stopCycle();
        if (!mounted) return;
        setState(() => _processing = false);
        _showAiFailedDialog(text, email, db);
        return;
      }

      final noteId = await db.insert('notes', {
        'user_email': email,
        'raw_text':   text,
        'summary':    aiResult.summary,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (aiResult.items.isNotEmpty) {
        final batch = db.batch();
        for (final item in aiResult.items) {
          batch.insert('note_items', {
            'note_id':  noteId,
            'type':     item.type,
            'content':  item.content,
            'due_date': item.dueDate,
          });
        }
        await batch.commit(noResult: true);
      }

      _stopCycle();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/history');
    } catch (_) {
      _stopCycle();
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan. Coba lagi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── AI failed dialog ─────────────────────────────────────────────────────
  Future<void> _showAiFailedDialog(
      String text, String email, dynamic db) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.cloud_off_outlined,
                color: Colors.white38, size: 44),
            const SizedBox(height: 12),
            const Text('Koneksi Terputus',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Tidak dapat terhubung ke AI.\nSimpan dulu, analisis bisa dilakukan nanti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await db.insert('notes', {
                        'user_email': email,
                        'raw_text':   text,
                        'summary':    '',
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/history');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Text('Simpan Saja',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _letGo();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1B3FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Coba Lagi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF13132B),
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildTextArea()),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 25,
            child: const AppNavBar(currentIndex: 2),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white54, size: 20),
        ),
        const Text('Catatan Baru',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(width: 32),
      ],
    );
  }

  // ── Text area ─────────────────────────────────────────────────────────────
  Widget _buildTextArea() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF161635)
            .withValues(alpha: _processing ? 0.35 : 0.7),
        border: Border.all(
          color: _isListening
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: _isListening ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Text field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
            child: TextField(
              controller: _ctrl,
              enabled: !_processing,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                  fontSize: 20, color: Colors.white, height: 1.5),
              decoration: const InputDecoration(
                hintText:
                    'Tulis atau ucapkan\nsemua yang ada\ndi pikiranmu...',
                hintStyle: TextStyle(
                    fontSize: 24, color: Colors.white24, height: 1.4),
                border: InputBorder.none,
              ),
            ),
          ),

          // Indikator rekam (atas)
          if (_isListening)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent),
                    ),
                    const SizedBox(width: 7),
                    const Text('Sedang merekam... ketuk mic untuk berhenti',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_processing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1E).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                          color: const Color(0xFFD1B3FF)
                              .withValues(alpha: 0.7),
                          strokeWidth: 1.2,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.18),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut)),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _loadingCopy[_loadingIdx],
                          key: ValueKey(_loadingIdx),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tombol mic (bawah tengah)
          if (!_processing)
            Positioned(
              bottom: 12, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleMic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : const Color(0xFF1E1E3F)
                              .withValues(alpha: 0.85),
                      border: _isListening
                          ? Border.all(
                              color: Colors.redAccent
                                  .withValues(alpha: 0.5),
                              width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: _isListening
                          ? Colors.redAccent
                          : Colors.white38,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _processing ? null : _letGo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: _processing
              ? const Color(0xFFD1B3FF).withValues(alpha: 0.4)
              : const Color(0xFFD1B3FF),
          borderRadius: BorderRadius.circular(30),
          boxShadow: _processing
              ? []
              : [
                  BoxShadow(
                      color: const Color(0xFFD1B3FF)
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
        ),
        child: _processing
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Color(0xFF13132B), strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Sebentar...',
                      style: TextStyle(
                          color: Color(0xFF13132B),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LEPASKAN',
                      style: TextStyle(
                          color: Color(0xFF13132B),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome,
                      color: Color(0xFF13132B), size: 18),
                ],
              ),
      ),
    );
  }
}
