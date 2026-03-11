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
      version: 7,
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
        message_count INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0 
      )
    ''');
    
    // Feedbacks Table
    await db.execute('''
      CREATE TABLE feedbacks(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        user_id INTEGER,
        type TEXT,
        content TEXT,
        latitude REAL,
        longitude REAL,
        address TEXT,
        photos TEXT,
        created_at INTEGER,
        status TEXT DEFAULT 'ACTIVE',
        view_count INTEGER DEFAULT 0,
        confirm_count INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        user_name TEXT
      )
    ''');
    
    await _createMessageTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMessageTables(db);
    }
    if (oldVersion < 3) {
      // Feedbacks Table
      await db.execute('''
        CREATE TABLE feedbacks(
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id INTEGER UNIQUE,
          user_id INTEGER,
          type TEXT,
          content TEXT,
          latitude REAL,
          longitude REAL,
          address TEXT,
          photos TEXT,
          created_at INTEGER,
          status TEXT DEFAULT 'ACTIVE',
          view_count INTEGER DEFAULT 0,
          confirm_count INTEGER DEFAULT 0,
          sync_status INTEGER DEFAULT 0,
          user_name TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add user_name column to feedbacks table if it doesn't exist
      // Since SQLite doesn't support IF NOT EXISTS for ADD COLUMN in all versions easily,
      // we just try to add it.
      try {
        await db.execute('ALTER TABLE feedbacks ADD COLUMN user_name TEXT');
      } catch (e) {
        debugPrint('Error adding user_name column: $e');
      }
    }
    if (oldVersion < 5) {
      // Add missing columns to hiking_records
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN coordinates_json TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN map_snapshot_url TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN message_count INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 6) {
      // Ensure message_count column exists
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN message_count INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 7) {
      // Ensure message_count column exists (again, for cases where v6 didn't have it due to missing onCreate)
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN message_count INTEGER DEFAULT 0'); } catch (_) {}
    }
  }
  
  Future<void> _createMessageTables(Database db) async {
    // Messages Table
    await db.execute('''
      CREATE TABLE messages(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        sender_id INTEGER,
        receiver_id INTEGER,
        content TEXT,
        type TEXT,
        timestamp INTEGER,
        is_read INTEGER DEFAULT 0,
        hike_id INTEGER,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Contacts/Friends Table
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY, 
        nickname TEXT,
        avatar TEXT,
        updated_at INTEGER
      )
    ''');
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

  // --- Message Helper Methods ---

  Future<int> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(int partnerId, int currentUserId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))',
      whereArgs: [currentUserId, partnerId, partnerId, currentUserId],
      orderBy: 'timestamp ASC',
    );
  }
  
  Future<Map<String, dynamic>?> getLastMessage(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.query(
      'messages',
      where: '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))',
      whereArgs: [currentUserId, partnerId, partnerId, currentUserId],
      orderBy: 'timestamp DESC',
      limit: 1
    );
    return res.isNotEmpty ? res.first : null;
  }
  
  Future<int> getUnreadCount(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE sender_id = ? AND receiver_id = ? AND is_read = 0',
      [partnerId, currentUserId]
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<int>> getUnreadMessageIds(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.query(
      'messages',
      columns: ['remote_id'],
      where: 'sender_id = ? AND receiver_id = ? AND is_read = 0 AND remote_id IS NOT NULL',
      whereArgs: [partnerId, currentUserId],
    );
    return res.map((e) => e['remote_id'] as int).toList();
  }

  Future<void> markMessagesAsRead(int partnerId, int currentUserId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'sender_id = ? AND receiver_id = ? AND is_read = 0',
      whereArgs: [partnerId, currentUserId],
    );
  }

  Future<int> associateMessagesWithHike(int hikeId, int userId, int startTime, int endTime) async {
    final db = await database;
    return await db.update(
      'messages',
      {'hike_id': hikeId},
      where: '((sender_id = ? OR receiver_id = ?) AND timestamp >= ? AND timestamp <= ?)',
      whereArgs: [userId, userId, startTime * 1000, endTime * 1000],
    );
  }

  Future<List<Map<String, dynamic>>> getMessagesByHikeId(int hikeId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'hike_id = ?',
      whereArgs: [hikeId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> saveContact(Map<String, dynamic> contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getContacts() async {
    final db = await database;
    return await db.query('contacts');
  }
  
  Future<Map<String, dynamic>?> getContact(int id) async {
    final db = await database;
    final res = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }
  
  // --- Feedback Helper Methods ---

  Future<int> saveFeedback(Map<String, dynamic> feedback) async {
    final db = await database;
    return await db.insert(
      'feedbacks',
      feedback,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFeedbacks(int userId) async {
    final db = await database;
    return await db.query(
      'feedbacks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteFeedback(int localId) async {
    final db = await database;
    await db.delete('feedbacks', where: 'local_id = ?', whereArgs: [localId]);
  }
}
