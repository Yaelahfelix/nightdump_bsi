import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class AiResult {
  final String summary;
  final List<NoteItem> items;

  const AiResult({required this.summary, required this.items});
}

class NoteItem {
  final String type; // todo | reminder | target | insight
  final String content;
  final String? dueDate; // "YYYY-MM-DD HH:mm" atau null

  const NoteItem({
    required this.type,
    required this.content,
    this.dueDate,
  });
}

class AiService {
  Future<AiResult?> analyzeNote(String text, {String? mood}) async {
    if (text.trim().isEmpty) return null;

    final input = text.trim();

    final now = DateTime.now();
    String fmt(DateTime d) {
      String p(int v) => v.toString().padLeft(2, '0');
      return '${d.year}-${p(d.month)}-${p(d.day)}';
    }

    final todayStr    = fmt(now);
    final tomorrowStr = fmt(now.add(const Duration(days: 1)));
    final lusaStr     = fmt(now.add(const Duration(days: 2)));
    final dayName     = _dayName(now.weekday);

    final moodCtx = (mood != null && mood.isNotEmpty)
        ? '\nMood pengguna: $mood.'
        : '';

    // Few-shot: contoh konkret dengan tanggal yang sudah dihitung
    // agar model tidak salah format / salah konversi waktu relatif
    final systemPrompt =
        'Hari ini $dayName, $todayStr.$moodCtx\n'
        'Ekstrak todo, reminder, target, insight dari catatan.\n'
        'Konversi waktu relatif: '
        'besok=$tomorrowStr, lusa=$lusaStr, '
        'pagi≈07:00, siang≈12:00, sore≈17:00, malam≈20:00.\n'
        'Balas HANYA JSON valid (tanpa markdown, tanpa teks lain):\n'
        '{"summary":"ringkasan catatan",'
        '"items":['
        '{"type":"todo","content":"beli telur","due_date":"$tomorrowStr 07:00"},'
        '{"type":"reminder","content":"bayar listrik","due_date":null},'
        '{"type":"insight","content":"contoh insight","due_date":null}'
        ']}';

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.deepseekBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.deepseekApiKey}',
            },
            body: jsonEncode({
              'model': AppConfig.deepseekModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': input},
              ],
              'stream': false,
              'max_tokens': 2000,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['choices'][0]['message']['content'] as String;
      return _parse(raw);
    } catch (_) {
      return null;
    }
  }

  AiResult? _parse(String raw) {
    try {
      var clean = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      // Jika ada teks di luar JSON, cari blok { ... } terluar
      if (!clean.startsWith('{')) {
        final m = RegExp(r'\{.+\}', dotAll: true).firstMatch(clean);
        if (m != null) clean = m.group(0)!;
      }

      final data = jsonDecode(clean) as Map<String, dynamic>;
      final items = (data['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((i) => NoteItem(
                type: (i['type'] as String? ?? 'insight').toLowerCase(),
                content: (i['content'] as String? ?? '').trim(),
                dueDate: _safeDue(i['due_date']),
              ))
          .where((i) => i.content.isNotEmpty)
          .toList();

      return AiResult(
        summary: (data['summary'] as String? ?? '').trim(),
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  /// Konversi "null" string / nilai lain ke null yang benar.
  String? _safeDue(dynamic val) {
    if (val == null || val == 'null' || val == '') return null;
    return val as String?;
  }

  String _dayName(int weekday) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    return days[weekday - 1];
  }
}
