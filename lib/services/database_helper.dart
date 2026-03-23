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
      version: 17,
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
        start_latitude REAL,
        start_longitude REAL,
        end_latitude REAL,
        end_longitude REAL,
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
        forward_count INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        user_name TEXT,
        user_avatar TEXT
      )
    ''');
    
    await _createMessageTables(db);
    await _createSOSEventTables(db);
    await _createFriendMessageTables(db);
    await _createTempFriendshipTable(db);
    await _createFeedbackCommentsTable(db);
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
    if (oldVersion < 8) {
      // Add sender_hike_id and receiver_hike_id to messages
      try { await db.execute('ALTER TABLE messages ADD COLUMN sender_hike_id INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN receiver_hike_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 9) {
      await _createSOSEventTables(db);
    }
    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE feedbacks ADD COLUMN user_avatar TEXT'); } catch (_) {}
    }
    if (oldVersion < 12) {
      await _createFeedbackCommentsTable(db);
    }
    if (oldVersion < 13) {
      try { await db.execute('ALTER TABLE feedback_comments ADD COLUMN user_avatar TEXT'); } catch (_) {}
    }
    if (oldVersion < 14) {
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN start_latitude REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN start_longitude REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN end_latitude REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE hiking_records ADD COLUMN end_longitude REAL'); } catch (_) {}
    }
    if (oldVersion < 15) {
      try { await db.execute('ALTER TABLE contacts ADD COLUMN owner_id INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 16) {
      // Create new index for faster range queries on messages if needed
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)'); } catch (_) {}
    }
    if (oldVersion < 17) {
      try { await db.execute('ALTER TABLE feedbacks ADD COLUMN forward_count INTEGER DEFAULT 0'); } catch (_) {}
      await _createTempFriendshipTable(db);
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
        sender_hike_id INTEGER,
        receiver_hike_id INTEGER,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Contacts/Friends Table
    await db.execute('''
      CREATE TABLE contacts(
        id INTEGER PRIMARY KEY, 
        nickname TEXT,
        avatar TEXT,
        updated_at INTEGER,
        owner_id INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createSOSEventTables(Database db) async {
    // 一次 SOS 求救事件（用于“我的求救”折叠展示）
    await db.execute('''
      CREATE TABLE sos_events(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        user_id INTEGER,
        message_json TEXT,
        recipients_json TEXT,
        photos_json TEXT,
        created_at INTEGER
      )
    ''');
  }

  Future<void> _createFriendMessageTables(Database db) async {
    await db.execute('''
      CREATE TABLE friend_messages(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        sender_id INTEGER,
        receiver_id INTEGER,
        content TEXT,
        type TEXT,
        timestamp INTEGER,
        is_read INTEGER DEFAULT 0,
        attachment_url TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createTempFriendshipTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS temp_friendships(
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_id INTEGER,
        partner_id INTEGER,
        partner_name TEXT,
        partner_avatar TEXT,
        last_message TEXT,
        last_message_type TEXT,
        last_timestamp INTEGER,
        updated_at INTEGER,
        UNIQUE(owner_id, partner_id)
      )
    ''');
  }

  Future<void> _createFeedbackCommentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE feedback_comments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER UNIQUE,
        feedback_id INTEGER,
        user_id INTEGER,
        user_name TEXT,
        user_avatar TEXT,
        content TEXT,
        created_at INTEGER
      )
    ''');
  }

  Future<int> saveSOSEvent(Map<String, dynamic> event) async {
    final db = await database;
    return await db.insert(
      'sos_events',
      event,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSOSEvents(int userId) async {
    final db = await database;
    return await db.query(
      'sos_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
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
    
    // Filter out keys that don't exist in the messages table
    final allowedKeys = {
      'local_id',
      'remote_id',
      'sender_id',
      'receiver_id',
      'content',
      'type',
      'timestamp',
      'is_read',
      'hike_id',
      'sender_hike_id',
      'receiver_hike_id',
      'sync_status'
    };
    
    final filtered = Map<String, dynamic>.from(message)
      ..removeWhere((key, value) => !allowedKeys.contains(key));
      
    return await db.insert(
      'messages',
      filtered,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 用服务端返回的 remote_id、timestamp 等更新已存在的本地消息，避免重复插入
  Future<void> updateMessageByLocalId(int localId, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'messages',
      updates,
      where: 'local_id = ?',
      whereArgs: [localId],
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

  // --- Friend Message Helper Methods (好友消息，仅成为好友后的对话) ---

  Future<int> saveFriendMessage(Map<String, dynamic> message) async {
    final db = await database;
    // 只保留 friend_messages 表真实存在的列，避免多余字段导致 SQLite 报错
    final allowedKeys = {
      'local_id',
      'remote_id',
      'sender_id',
      'receiver_id',
      'content',
      'type',
      'timestamp',
      'is_read',
      'attachment_url',
      'sync_status',
    };
    final filtered = Map<String, dynamic>.from(message)
      ..removeWhere((key, value) => !allowedKeys.contains(key));

    return await db.insert(
      'friend_messages',
      filtered,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFriendMessageByLocalId(int localId, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'friend_messages',
      updates,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getFriendMessages(int partnerId, int currentUserId) async {
    final db = await database;
    return await db.query(
      'friend_messages',
      where: '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))',
      whereArgs: [currentUserId, partnerId, partnerId, currentUserId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<Map<String, dynamic>?> getLastFriendMessage(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.query(
      'friend_messages',
      where: '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))',
      whereArgs: [currentUserId, partnerId, partnerId, currentUserId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> getUnreadFriendCount(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM friend_messages WHERE sender_id = ? AND receiver_id = ? AND is_read = 0',
      [partnerId, currentUserId],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<int>> getUnreadFriendMessageIds(int partnerId, int currentUserId) async {
    final db = await database;
    final res = await db.query(
      'friend_messages',
      columns: ['remote_id'],
      where: 'sender_id = ? AND receiver_id = ? AND is_read = 0 AND remote_id IS NOT NULL',
      whereArgs: [partnerId, currentUserId],
    );
    return res.map((e) => e['remote_id'] as int).toList();
  }

  Future<void> markFriendMessagesAsRead(int partnerId, int currentUserId) async {
    final db = await database;
    await db.update(
      'friend_messages',
      {'is_read': 1},
      where: 'sender_id = ? AND receiver_id = ? AND is_read = 0',
      whereArgs: [partnerId, currentUserId],
    );
  }

  Future<int> associateMessagesWithHike(int hikeId, int userId, int startTime, int endTime) async {
    final db = await database;
    
    // 1. Update sender_hike_id for messages sent by user
    int senderCount = await db.update(
      'messages',
      {'sender_hike_id': hikeId},
      where: 'sender_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [userId, startTime * 1000, endTime * 1000],
    );

    // 2. Update receiver_hike_id for messages received by user
    int receiverCount = await db.update(
      'messages',
      {'receiver_hike_id': hikeId},
      where: 'receiver_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [userId, startTime * 1000, endTime * 1000],
    );

    return senderCount + receiverCount;
  }

  Future<List<Map<String, dynamic>>> getMessagesByHikeId(int hikeId, int currentUserId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: '(sender_id = ? AND sender_hike_id = ?) OR (receiver_id = ? AND receiver_hike_id = ?)',
      whereArgs: [currentUserId, hikeId, currentUserId, hikeId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getMessagesByTimeRange(int startTime, int endTime) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startTime, endTime],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> saveContact(Map<String, dynamic> contact, {int ownerId = 0}) async {
    final db = await database;
    final data = Map<String, dynamic>.from(contact);
    data['owner_id'] = ownerId;
    await db.insert(
      'contacts',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getContacts(int ownerId) async {
    final db = await database;
    return await db.query('contacts', where: 'owner_id = ?', whereArgs: [ownerId]);
  }
  
  Future<Map<String, dynamic>?> getContact(int id, {int ownerId = 0}) async {
    final db = await database;
    final res = await db.query('contacts', where: 'id = ? AND owner_id = ?', whereArgs: [id, ownerId]);
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

  Future<int> saveTempFriendship(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'temp_friendships',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTempFriendships(int ownerId) async {
    final db = await database;
    return await db.query(
      'temp_friendships',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'last_timestamp DESC',
    );
  }

  Future<int> saveFeedbackComment(Map<String, dynamic> comment) async {
    final db = await database;
    return await db.insert(
      'feedback_comments',
      comment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFeedbackComments(int feedbackId) async {
    final db = await database;
    return await db.query(
      'feedback_comments',
      where: 'feedback_id = ?',
      whereArgs: [feedbackId],
      orderBy: 'created_at DESC',
    );
  }
}
