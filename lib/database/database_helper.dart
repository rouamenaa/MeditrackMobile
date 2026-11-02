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
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createV1(db);
        await _migrateToV2(db);
        await _migrateToV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
        if (oldVersion < 3) await _migrateToV3(db);
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

  /// v3 — Module médicaments (catalogue personnel)
  Future<void> _migrateToV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medications (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id               INTEGER NOT NULL,
        name                  TEXT    NOT NULL,
        dosage                TEXT,
        form                  TEXT    NOT NULL DEFAULT 'comprime',
        manufacturer          TEXT,
        description           TEXT,
        stock_quantity        INTEGER,
        stock_alert_threshold INTEGER,
        expiry_date           TEXT,
        barcode               TEXT,
        created_at            TEXT    NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}