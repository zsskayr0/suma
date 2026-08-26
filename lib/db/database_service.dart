import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/entry.dart';
import '../models/user.dart';

/// Owns the single local SQLite database that backs the whole app.
///
/// On Windows/Linux desktop we use `sqflite_common_ffi` (sqlite3 is bundled
/// via `sqlite3_flutter_libs`); on Android the regular `sqflite` plugin
/// talks to the platform's built-in SQLite. Either way the rest of the app
/// only ever calls this class - never `sqflite` directly.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'suma.db');

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('admin', 'member')),
            created_at TEXT NOT NULL,
            height_cm REAL,
            goal_weight_kg REAL,
            unit_pref TEXT NOT NULL DEFAULT 'kg',
            theme_pref TEXT NOT NULL DEFAULT 'system',
            onboarded INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            date TEXT NOT NULL,
            weight_kg REAL NOT NULL,
            body_fat_pct REAL,
            hydration_pct REAL,
            notes TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_entries_user_date ON entries(user_id, date)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN height_cm REAL');
          await db.execute('ALTER TABLE users ADD COLUMN goal_weight_kg REAL');
          await db.execute("ALTER TABLE users ADD COLUMN unit_pref TEXT NOT NULL DEFAULT 'kg'");
          await db.execute("ALTER TABLE users ADD COLUMN theme_pref TEXT NOT NULL DEFAULT 'system'");
          await db.execute('ALTER TABLE users ADD COLUMN onboarded INTEGER NOT NULL DEFAULT 0');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ---------------- Users ----------------

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'name COLLATE NOCASE');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<bool> hasAnyUser() async {
    final db = await database;
    final rows = await db.query('users', limit: 1);
    return rows.isNotEmpty;
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> createUser(AppUser user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap()..remove('id'));
    return user.copyWith(id: id);
  }

  Future<void> updateUser(AppUser user) async {
    final db = await database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countAdmins() async {
    final db = await database;
    final rows = await db.query('users', where: "role = 'admin'");
    return rows.length;
  }

  // ---------------- Entries ----------------

  Future<List<WeightEntry>> getEntriesForUser(int userId) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<WeightEntry> createEntry(WeightEntry entry) async {
    final db = await database;
    final id = await db.insert('entries', entry.toMap()..remove('id'));
    return entry.copyWith(id: id);
  }

  Future<void> updateEntry(WeightEntry entry) async {
    final db = await database;
    await db.update('entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
}
