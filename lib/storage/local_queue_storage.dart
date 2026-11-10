import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_status.dart';

class LocalQueueStorage {
  static Database? _database;
  static final List<Map<String, dynamic>> _webClients = [];

  Future<Database> get database async {
    if (_database != null) return _database!;

    final path = join(await getDatabasesPath(), 'waiting_queue.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            lat REAL,
            lng REAL,
            location_accuracy_m REAL,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<void> saveClient(Map<String, dynamic> client) async {
    if (kIsWeb) {
      _webClients.removeWhere((c) => c['id'].toString() == client['id'].toString());
      _webClients.add(Map<String, dynamic>.from(client));
      return;
    }
    final db = await database;
    await db.insert(
      'clients',
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (kIsWeb) {
      final list = List<Map<String, dynamic>>.from(_webClients);
      list.sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
      return list;
    }
    final db = await database;
    return db.query('clients', orderBy: 'created_at DESC, id DESC');
  }

  /// Corrected: Fetches both 'pending' and 'failed' records for retry logic
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    if (kIsWeb) {
      return _webClients
          .where((c) =>
              c['sync_status'] == SyncStatus.pending.name ||
              c['sync_status'] == SyncStatus.failed.name)
          .toList();
    }
    final db = await database;
    return db.query(
      'clients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    if (kIsWeb) {
      final idx = _webClients.indexWhere((c) => c['id'].toString() == id);
      if (idx != -1) {
        _webClients[idx]['sync_status'] = status.name;
      }
      return;
    }
    final db = await database;
    await db.update(
      'clients',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteClient(String id) async {
    if (kIsWeb) {
      _webClients.removeWhere((c) => c['id'].toString() == id);
      return;
    }
    final db = await database;
    await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

