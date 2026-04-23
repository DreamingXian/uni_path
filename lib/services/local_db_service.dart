import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDBService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'unipath_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE local_schedules(
            id TEXT PRIMARY KEY,
            title TEXT,
            location_name TEXT,
            start_time TEXT,
            is_homework INTEGER
          )
        ''');
      },
    );
  }

  Future<void> saveLocally(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('local_schedules', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cacheData(List<Map<String, dynamic>> schedules) async {
    final db = await database;
    Batch batch = db.batch();
    batch.delete('local_schedules');
    for (var s in schedules) {
      batch.insert('local_schedules', {
        'id': s['id'].toString(),
        'title': s['title'],
        'location_name': s['location_name'],
        'start_time': s['start_time'],
        'is_homework': s['is_homework'] == true ? 1 : 0,
      });
    }
    await batch.commit();
  }

  Future<void> deleteLocally(String id) async {
    final db = await database;
    await db.delete('local_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> fetchOfflineSchedules() async {
    final db = await database;
    return await db.query('local_schedules', orderBy: 'start_time ASC');
  }
}