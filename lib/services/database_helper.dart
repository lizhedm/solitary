import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'solitary_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // User Table
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY,
        username TEXT,
        email TEXT,
        nickname TEXT,
        avatar TEXT,
        phone TEXT,
        wechat_openid TEXT,
        is_active INTEGER,
        is_hiking INTEGER DEFAULT 0,
        current_lat REAL,
        current_lng REAL,
        location_updated_at INTEGER,
        visible_on_map INTEGER DEFAULT 1,
        visible_range INTEGER DEFAULT 5,
        receive_sos INTEGER DEFAULT 1,
        receive_questions INTEGER DEFAULT 1,
        receive_feedback INTEGER DEFAULT 1,
        last_synced_at INTEGER
      )
    ''');

    // Hiking Records Table
    // remote_id can be null for locally created but not yet synced records
    await db.execute('''
      CREATE TABLE hiking_records(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE, 
        user_id INTEGER,
        start_time INTEGER,
        end_time INTEGER,
        duration INTEGER,
        distance REAL,
        calories INTEGER,
        elevation_gain INTEGER,
        start_location TEXT,
        end_location TEXT,
        map_snapshot_url TEXT,
        coordinates_json TEXT,
        sync_status INTEGER DEFAULT 0 
      )
    ''');
    // sync_status: 0 = synced, 1 = pending upload
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations
  }

  // --- User Helper Methods ---

  Future<int> saveUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(
      'users',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUser(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  
  Future<void> clearUser() async {
    final db = await database;
    await db.delete('users');
  }

  // --- Hiking Record Helper Methods ---

  Future<int> saveHikingRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert(
      'hiking_records',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHikingRecords(int userId) async {
    final db = await database;
    return await db.query(
      'hiking_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time DESC',
    );
  }
  
  Future<void> deleteHikingRecords(int userId) async {
    final db = await database;
    await db.delete('hiking_records', where: 'user_id = ?', whereArgs: [userId]);
  }
}
