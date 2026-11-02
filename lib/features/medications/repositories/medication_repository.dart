/// ============================================================
/// Module MÉDICAMENTS : repository CRUD + gestion du stock
///
/// Réutilise la base `meditrack.db` de l'équipe (DatabaseHelper
/// partagé). NE MODIFIE PAS ce fichier : nos tables sont créées
/// avec CREATE TABLE IF NOT EXISTS -> pas de conflit au merge.
///
/// Règles métier :
///  - Un médicament appartient à UN utilisateur (user_id)
///  - Le stock peut être décrémenté / incrémenté
///  - Recherche par nom (LIKE insensible à la casse)
///  - Alerte si stock <= seuil configuré
/// ============================================================
library;

import 'package:meditrackmobile/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../models/medication.dart';

class MedicationRepository {
  MedicationRepository._ctor();
  static final MedicationRepository instance = MedicationRepository._ctor();
  factory MedicationRepository() => instance;

  Database? _memo;

  Future<Database> get _db async {
    _memo ??= await _open();
    return _memo!;
  }

  Future<Database> _open() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medications (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id              INTEGER NOT NULL,
        name                 TEXT    NOT NULL,
        dosage               TEXT,
        form                 TEXT    NOT NULL DEFAULT 'comprime',
        manufacturer         TEXT,
        description          TEXT,
        stock_quantity       INTEGER,
        stock_alert_threshold INTEGER,
        expiry_date          TEXT,
        barcode              TEXT,
        created_at           TEXT    NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    return db;
  }

  // ================= CREATE =================

  Future<Medication> create(Medication med) async {
    final db = await _db;
    final map = med.toMap()..remove('id');
    final id = await db.insert('medications', map);
    return _getById(id);
  }

  // ================= READ =================

  Future<Medication?> byIdForUser(int id, int userId) async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : Medication.fromMap(rows.first);
  }

  /// Tous les médicaments d'un utilisateur, triés par nom
  Future<List<Medication>> allForUser(int userId) async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  /// Recherche par nom (insensible à la casse, recherche partielle)
  Future<List<Medication>> search(int userId, String query) async {
    if (query.trim().isEmpty) return allForUser(userId);
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'user_id = ? AND LOWER(name) LIKE ?',
      whereArgs: [userId, '%${query.toLowerCase()}%'],
      orderBy: 'name ASC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  /// Médicaments dont le stock est en alerte (stock <= seuil)
  Future<List<Medication>> lowStock(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT * FROM medications
      WHERE user_id = ?
        AND stock_quantity IS NOT NULL
        AND stock_alert_threshold IS NOT NULL
        AND stock_quantity <= stock_alert_threshold
      ORDER BY stock_quantity ASC
    ''', [userId]);
    return rows.map(Medication.fromMap).toList();
  }

  /// Médicaments qui expirent dans les 30 prochains jours (ou déjà expirés)
  Future<List<Medication>> expiringSoon(int userId) async {
    final db = await _db;
    final soon = DateTime.now().add(const Duration(days: 30));
    final soonStr =
        '${soon.year}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery('''
      SELECT * FROM medications
      WHERE user_id = ?
        AND expiry_date IS NOT NULL
        AND expiry_date <= ?
      ORDER BY expiry_date ASC
    ''', [userId, soonStr]);
    return rows.map(Medication.fromMap).toList();
  }

  // ================= UPDATE =================

  Future<int> update(Medication med) async {
    final db = await _db;
    return db.update(
      'medications',
      med.toMap()..remove('id'),
      where: 'id = ? AND user_id = ?',
      whereArgs: [med.id, med.userId],
    );
  }

  /// Décrémenter le stock d'une unité (ex : lors d'une prise)
  /// Retourne false si stock déjà à 0 ou non suivi.
  Future<bool> decrementStock(int id, int userId) async {
    final db = await _db;
    final med = await byIdForUser(id, userId);
    if (med == null || med.stockQuantity == null || med.stockQuantity! <= 0) {
      return false;
    }
    await db.update(
      'medications',
      {'stock_quantity': med.stockQuantity! - 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    return true;
  }

  /// Incrémenter le stock (ex : renouvellement d'ordonnance)
  Future<void> incrementStock(int id, int userId, int amount) async {
    final db = await _db;
    final med = await byIdForUser(id, userId);
    if (med == null || med.stockQuantity == null) return;
    await db.update(
      'medications',
      {'stock_quantity': med.stockQuantity! + amount},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ================= DELETE =================

  Future<int> delete(int id, int userId) async {
    final db = await _db;
    return db.delete(
      'medications',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ================= Utilitaires privées =================

  Future<Medication> _getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return Medication.fromMap(rows.first);
  }
}
