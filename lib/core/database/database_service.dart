/// Markdown Logger - Core Database Service
/// 
/// Handles SQLite database operations for all plugins
library;

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'markdown_logger.db';
  
  // Singleton instance for settings screen
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();
  
  // Clear all data
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('log_entries');
    await db.delete('app_meta');
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // App metadata table
    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Generic log entries table
    await db.execute('''
      CREATE TABLE log_entries (
        id TEXT PRIMARY KEY,
        plugin_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        date TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_log_entries_date ON log_entries(date)
    ''');
    await db.execute('''
      CREATE INDEX idx_log_entries_plugin ON log_entries(plugin_id)
    ''');
  }

  // CRUD Operations
  static Future<void> insertEntry(Map<String, dynamic> entry) async {
    final db = await database;
    await db.insert('log_entries', entry, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getEntriesByDate(String date) async {
    final db = await database;
    return await db.query('log_entries', where: 'date = ?', whereArgs: [date]);
  }

  static Future<List<Map<String, dynamic>>> getEntriesByPlugin(String pluginId, String date) async {
    final db = await database;
    return await db.query(
      'log_entries',
      where: 'plugin_id = ? AND date = ?',
      whereArgs: [pluginId, date],
    );
  }

  static Future<void> updateEntry(String id, Map<String, dynamic> entry) async {
    final db = await database;
    await db.update('log_entries', entry, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('log_entries', where: 'id = ?', whereArgs: [id]);
  }

  // App metadata operations
  static Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('app_meta', {'key': key, 'value': value}, 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getMeta(String key) async {
    final db = await database;
    final result = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }
}
