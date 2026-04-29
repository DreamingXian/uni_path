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
      version: 2, // Incremented version for new columns
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE local_schedules(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            description TEXT,
            location_name TEXT,
            start_time TEXT,
            end_time TEXT,
            label_name TEXT,
            is_homework INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          // Simplest upgrade: drop and recreate
          db.execute("DROP TABLE IF EXISTS local_schedules");
          db.execute('''
            CREATE TABLE local_schedules(
              id TEXT PRIMARY KEY,
              user_id TEXT,
              title TEXT,
              description TEXT,
              location_name TEXT,
              start_time TEXT,
              end_time TEXT,
              label_name TEXT,
              is_homework INTEGER
            )
          ''');
        }
      },
    );
  }

  // FIXED: Added the missing saveLocally method for ScheduleService
  Future<void> saveLocally(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
        'local_schedules',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<void> cacheData(List<Map<String, dynamic>> schedules) async {
    final db = await database;
    Batch batch = db.batch();
    batch.delete('local_schedules');
    for (var s in schedules) {
      batch.insert('local_schedules', {
        'id': s['id'].toString(),
        'user_id': s['user_id'],
        'title': s['title'],
        'description': s['description'],
        'location_name': s['location_name'],
        'start_time': s['start_time'],
        'end_time': s['end_time'],
        'label_name': s['label_name'],
        'is_homework': (s['is_homework'] == true || s['is_homework'] == 1) ? 1 : 0,
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