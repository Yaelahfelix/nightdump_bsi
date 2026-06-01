import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class AuthService {
  final _dbHelper = DatabaseHelper();

  static const _sessionKey = 'current_user';

  String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  // Mengembalikan pesan error, null jika berhasil.
  Future<String?> register(String name, String email, String password) async {
    if (name.trim().isEmpty) return 'Nama tidak boleh kosong.';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim())) {
      return 'Format email tidak valid.';
    }
    if (password.length < 6) return 'Password minimal 6 karakter.';

    final db = await _dbHelper.db;
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) return 'Email sudah terdaftar.';

    await db.insert('users', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password_hash': _hash(password),
      'created_at': DateTime.now().toIso8601String(),
    });

    await _setSession(email.trim().toLowerCase());
    return null;
  }

  // Mengembalikan pesan error, null jika berhasil.
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty) return 'Email tidak boleh kosong.';
    if (password.isEmpty) return 'Password tidak boleh kosong.';

    final db = await _dbHelper.db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) return 'Email tidak ditemukan.';
    if (rows.first['password_hash'] != _hash(password)) {
      return 'Password salah.';
    }

    await _setSession(email.trim().toLowerCase());
    return null;
  }

  Future<void> logout() async {
    final db = await _dbHelper.db;
    await db.delete('settings', where: 'key = ?', whereArgs: [_sessionKey]);
  }

  Future<bool> isLoggedIn() async {
    final db = await _dbHelper.db;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_sessionKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, String>?> getCurrentUser() async {
    final db = await _dbHelper.db;
    final session = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_sessionKey],
      limit: 1,
    );
    if (session.isEmpty) return null;

    final email = session.first['value'] as String;
    final users = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (users.isEmpty) return null;

    return {
      'name': users.first['name'] as String,
      'email': users.first['email'] as String,
    };
  }

  Future<void> _setSession(String email) async {
    final db = await _dbHelper.db;
    await db.insert(
      'settings',
      {'key': _sessionKey, 'value': email},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
