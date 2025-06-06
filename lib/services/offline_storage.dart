import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alert.dart';

class OfflineStorage {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'traffic_alerts.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create local alerts table
        await db.execute('''
          CREATE TABLE local_alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remote_id INTEGER,
            type TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            reported_at TEXT NOT NULL,
            confirmed_count INTEGER DEFAULT 1,
            is_active INTEGER DEFAULT 1,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Create cached map tiles table (optional)
        await db.execute('''
          CREATE TABLE map_tiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE,
            tile_data BLOB,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // Save alert locally
  Future<int> saveAlert(Alert alert) async {
    final db = await database;
    return await db.insert(
      'local_alerts',
      {
        'remote_id': alert.id,
        'type': alert.type,
        'latitude': alert.latitude,
        'longitude': alert.longitude,
        'reported_at': alert.reportedAt.toIso8601String(),
        'confirmed_count': alert.confirmedCount,
        'is_active': alert.isActive ? 1 : 0,
        'synced': 0,
      },
    );
  }

  // Get all local alerts
  Future<List<Alert>> getLocalAlerts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('local_alerts');
    
    return List.generate(maps.length, (i) {
      return Alert(
        id: maps[i]['remote_id'],
        type: maps[i]['type'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        reportedAt: DateTime.parse(maps[i]['reported_at']),
        confirmedCount: maps[i]['confirmed_count'],
        isActive: maps[i]['is_active'] == 1,
      );
    });
  }

  // Get all unsynced alerts
  Future<List<Map<String, dynamic>>> getUnsyncedAlerts() async {
    final db = await database;
    return await db.query(
      'local_alerts',
      where: 'synced = ?',
      whereArgs: [0],
    );
  }

  // Mark alert as synced
  Future<void> markAsSynced(int localId, int remoteId) async {
    final db = await database;
    await db.update(
      'local_alerts',
      {'synced': 1, 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }
  
  // Cache map tile (optional)
  Future<void> cacheMapTile(String url, List<int> tileData) async {
    final db = await database;
    await db.insert(
      'map_tiles',
      {
        'url': url,
        'tile_data': tileData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Get cached map tile (optional)
  Future<List<int>?> getCachedMapTile(String url) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'map_tiles',
      columns: ['tile_data'],
      where: 'url = ?',
      whereArgs: [url],
    );
    
    if (result.isNotEmpty) {
      return result.first['tile_data'] as List<int>;
    }
    return null;
  }
  
  // Clean old cached tiles older than 2 weeks (optional)
  Future<void> cleanOldTiles() async {
    final db = await database;
    final twoWeeksAgo = DateTime.now().subtract(Duration(days: 14)).millisecondsSinceEpoch;
    
    await db.delete(
      'map_tiles',
      where: 'timestamp < ?',
      whereArgs: [twoWeeksAgo],
    );
  }
}