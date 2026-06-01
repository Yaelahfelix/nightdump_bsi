import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _dbName = 'nightdump.db';
  static const _dbVersion = 4; // v4: tambah kolom due_date pada note_items

  static Database? _instance;

  Future<Database> get db async {
    _instance ??= await _open();
    return _instance!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createUsers(db);
    await _createSettings(db);
    await _createNotes(db);
    await _createNoteItems(db);
  }

  Future<void> _onUpgrade(Database db, int old, int next) async {
    if (old < 2) {
      await _createNotes(db);
      await _createNoteItems(db);
    }
    if (old < 3) {
      await db.execute(
        'ALTER TABLE note_items ADD COLUMN done INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (old < 4) {
      await db.execute('ALTER TABLE note_items ADD COLUMN due_date TEXT');
    }
  }

  Future<void> _createUsers(Database db) => db.execute('''
    CREATE TABLE users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      name          TEXT    NOT NULL,
      email         TEXT    UNIQUE NOT NULL,
      password_hash TEXT    NOT NULL,
      created_at    TEXT    NOT NULL
    )
  ''');

  Future<void> _createSettings(Database db) => db.execute('''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT
    )
  ''');

  Future<void> _createNotes(Database db) => db.execute('''
    CREATE TABLE notes (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT    NOT NULL,
      raw_text   TEXT    NOT NULL,
      summary    TEXT    NOT NULL DEFAULT '',
      created_at TEXT    NOT NULL
    )
  ''');

  Future<void> _createNoteItems(Database db) => db.execute('''
    CREATE TABLE note_items (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      note_id  INTEGER NOT NULL,
      type     TEXT    NOT NULL,
      content  TEXT    NOT NULL,
      done     INTEGER NOT NULL DEFAULT 0,
      due_date TEXT,
      FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    )
  ''');
}
