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
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createV1(db);
        await _migrateToV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
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
  }

  Future<void> _migrateToV2(Database db) async {
    const newColumns = [
      'date_creation',
      'photo_path',
      'groupe_sanguin',
      'condition_medicale',
      'contact_urgence_nom',
      'contact_urgence_lien',
      'contact_urgence_tel',
      'assurance_nom',
      'assurance_police',
    ];
    for (final col in newColumns) {
      await db.execute('ALTER TABLE users ADD COLUMN $col TEXT');
    }

    await db.execute('''
      CREATE TABLE medecins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        nom TEXT NOT NULL,
        specialite TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}