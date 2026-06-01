import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get deepseekApiKey =>
      dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  static String get deepseekBaseUrl =>
      dotenv.env['DEEPSEEK_BASE_URL'] ??
      'https://api.deepseek.com/chat/completions';
  static String get deepseekModel =>
      dotenv.env['DEEPSEEK_MODEL'] ?? 'deepseek-v4-flash';
}
