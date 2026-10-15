import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'meditrack.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            prenom TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            telephone TEXT,
            date_naissance TEXT,
            sexe TEXT,
            notif_medicaments INTEGER NOT NULL DEFAULT 1,
            notif_rdv INTEGER NOT NULL DEFAULT 1,
            notif_son INTEGER NOT NULL DEFAULT 1,
            notif_vibration INTEGER NOT NULL DEFAULT 1,
            rappel_avant_minutes INTEGER NOT NULL DEFAULT 10
          )
        ''');
      },
    );
  }
}