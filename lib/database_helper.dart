import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    String path = join(await getDatabasesPath(), 'files_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            "CREATE TABLE files(id INTEGER PRIMARY KEY, name TEXT, path TEXT);");
        await db.execute(
            "CREATE TABLE criteria(id INTEGER PRIMARY KEY, qualification TEXT, skill TEXT, experience TEXT, resumes_selected INTEGER);");
      },
    );
  }

  Future<void> insertFile(String name, String path) async {
    final db = await database;
    await db.insert(
      'files',
      {'name': name, 'path': path},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCriteria(String qualification, String skill,
      String experience, int resumesSelected) async {
    final db = await database;
    await db.insert(
      'criteria',
      {
        'qualification': qualification,
        'skill': skill,
        'experience': experience,
        'resumes_selected': resumesSelected
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFiles() async {
    final db = await database;
    return await db.query('files');
  }
}
