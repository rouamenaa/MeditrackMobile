/// ============================================================
/// Module 3.3 — TRAITEMENTS : repository CRUD + historique
///
/// Réutilise la base `meditrack.db` de l'équipe (DatabaseHelper
/// partagé) mais NE MODIFIE PAS ce fichier : on crée uniquement
/// nos tables avec `CREATE TABLE IF NOT EXISTS`. Chaque module
/// du groupe peut faire pareil sans conflit au merge.
///
/// Règles métier appliquées (doc §11) :
///  - endDate < startDate interdit (validé aussi côté formulaire)
///  - Stop : l'historique est conservé, les prises futures annulées
///  - Completed : attribué automatiquement quand endDate est passé
///  - Modifier dose/horaires régénère UNIQUEMENT les prises futures
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:meditrackmobile/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../models/treatment.dart';

/// Statistiques d'un jour (pour la mini courbe d'adhérence)
class DayStat {
  final DateTime day;
  final int taken;
  final int total;
  DayStat({required this.day, required this.taken, required this.total});
}

/// Résumé d'un traitement pour la liste (agrégats SQL + jointure)
class TreatmentSummary {
  final Treatment treatment;
  final int takenCount; // prises déjà "taken"
  final int pastCount; // prises dont l'horaire est déjà passé
  final DateTime? nextDose; // prochaine prise à venir
  TreatmentSummary(
      {required this.treatment,
      required this.takenCount,
      required this.pastCount,
      this.nextDose});

  /// Progression du plan (0.0 -> 1.0) affichée dans la carte
  double get progress =>
      pastCount == 0 ? 0 : (takenCount / pastCount).clamp(0.0, 1.0);
}

/// Vue d'ensemble (1 seul Future -> 1 seul FutureBuilder dans l'écran)
class TreatmentOverview {
  final double? adherence; // % pris/semaine (null = pas de données)
  final List<DayStat> week; // 7 derniers jours
  final List<TreatmentSummary> active;
  final List<TreatmentSummary> past; // terminés / arrêtés
  TreatmentOverview(
      {required this.adherence,
      required this.week,
      required this.active,
      required this.past});
}

/// Une dose à venir (jointure intake_logs + treatments)
/// -> alimente le service de notifications extras
class UpcomingDose {
  final IntakeLog log;
  final String medicationName;
  final String? dosage;
  final String dose;
  UpcomingDose(
      {required this.log,
      required this.medicationName,
      this.dosage,
      required this.dose});
}

class TreatmentRepository {
  // Singleton léger (pattern identique à DatabaseHelper)
  TreatmentRepository._ctor();
  static final TreatmentRepository instance = TreatmentRepository._ctor();
  factory TreatmentRepository() => instance;

  Database? _memo;

  Future<Database> get _db async {
    _memo ??= await _open();
    return _memo!;
  }

  Future<Database> _open() async {
    // Base partagée de l'équipe (users déjà à l'intérieur)
    final db = await DatabaseHelper.instance.database;
    // Uniquement NOS tables du module 3.3
    await db.execute('''
      CREATE TABLE IF NOT EXISTS treatments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        medication_name TEXT NOT NULL,
        medication_dosage TEXT,
        dose TEXT NOT NULL,
        reminder_times TEXT NOT NULL DEFAULT '08:00',
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS intake_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        treatment_id INTEGER NOT NULL,
        scheduled_at TEXT NOT NULL,
        taken_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (treatment_id) REFERENCES treatments(id) ON DELETE CASCADE
      )
    ''');
    return db;
  }

  final _now = DateTime.now; // évite les réécritures
  String get _nowIso => _now().toIso8601String();

  // ================= CRUD Treatment =================

  /// CREATE : insère le traitement puis génère son IntakeLog
  Future<Treatment> create(Treatment t) async {
    final db = await _db;
    final id = await db.insert('treatments', t.toMap()..remove('id'));
    final created = await _getById(id);
    await _generateLogs(created);
    return created;
  }

  /// READ (sécurité) : un traitement de CETTE utilisateur
  Future<Treatment?> byIdForUser(int id, int userId) async {
    final db = await _db;
    final rows = await db.query('treatments',
        where: 'id = ? AND user_id = ?', whereArgs: [id, userId], limit: 1);
    return rows.isEmpty ? null : Treatment.fromMap(rows.first);
  }

  /// Résumé frais d'UN traitement (compteurs + prochaine prise)
  /// -> utilisé après une modification pour rafraîchir l'écran historique.
  Future<TreatmentSummary?> summaryFor(int id, int userId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*,
        (SELECT COUNT(*) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.status = 'taken'
            AND l.scheduled_at <= ?) AS taken_count,
        (SELECT COUNT(*) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.scheduled_at <= ?) AS past_count,
        (SELECT MIN(scheduled_at) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.status = 'pending'
            AND l.scheduled_at >= ?) AS next_dose
      FROM treatments t
      WHERE t.id = ? AND t.user_id = ?
      LIMIT 1
    ''', [_nowIso, _nowIso, _nowIso, id, userId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final next = r['next_dose'] as String?;
    return TreatmentSummary(
      treatment: Treatment.fromMap(r),
      takenCount: (r['taken_count'] ?? 0) as int,
      pastCount: (r['past_count'] ?? 0) as int,
      nextDose: next == null ? null : DateTime.parse(next),
    );
  }

  Future<Treatment> _getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('treatments', where: 'id = ?', whereArgs: [id], limit: 1);
    return Treatment.fromMap(rows.first);
  }

  /// UPDATE : régénère uniquement les prises futures, l'histoire reste intacte.
  Future<int> update(Treatment t) async {
    final db = await _db;
    final count = await db.update(
      'treatments',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id], // ALWAYS where + whereArgs sur update !
    );
    final fresh = await _getById(t.id!);
    // Modification : prises futures régénérées, historique préservé
    await _deleteFutureLogs(fresh);
    if (fresh.status == TreatmentStatus.active ||
        fresh.status == TreatmentStatus.planned) {
      await _generateLogs(fresh, from: _dayStart(_now()));
    }
    return count;
  }

  /// DELETE (avec confirmation côté UI avant l'appel)
  Future<int> delete(int id) async {
    final db = await _db;
    // cascade manuelle : plus sûr que de dépendre du pragma
    await db.delete('intake_logs',
        where: 'treatment_id = ?', whereArgs: [id]);
    return db.delete('treatments', where: 'id = ?', whereArgs: [id]);
  }

  /// STOP du cycle de vie : historique conservé, futures prises annulées.
  Future<int> stop(int id) async {
    final db = await _db;
    final count = await db.update('treatments',
        {'status': TreatmentStatus.stopped.name},
        where: 'id = ?', whereArgs: [id]);
    await _deleteFutureLogsById(id);
    return count;
  }

  // ================= IntakeLog =================

  /// READ : historique complet d'un traitement (le plus récent d'abord)
  Future<List<IntakeLog>> logsOf(int treatmentId) async {
    final db = await _db;
    final rows = await db.query('intake_logs',
        where: 'treatment_id = ?',
        whereArgs: [treatmentId],
        orderBy: 'scheduled_at DESC');
    return rows.map(IntakeLog.fromMap).toList();
  }

  /// Marquer une prise : taken / skipped (l'historique n'est jamais supprimé)
  Future<int> markLog(int logId, IntakeStatus status) async {
    final db = await _db;
    return db.update(
      'intake_logs',
      {
        'status': status.name,
        'taken_at': status == IntakeStatus.taken ? _nowIso : null,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [logId, IntakeStatus.pending.name],
    );
  }

  /// Bouton "Valider la prise" de la carte : marque la prochaine prise
  /// du jour (la plus proche) comme prise.
  Future<bool> logNextDose(int treatmentId) async {
    final db = await _db;
    final rows = await db.query(
      'intake_logs',
      where:
          'treatment_id = ? AND status = ? AND scheduled_at < ? '
          'AND scheduled_at >= ?',
      whereArgs: [
        treatmentId,
        IntakeStatus.pending.name,
        _nowIso,
        _dayToIso(_now()),
      ],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    await markLog(rows.first['id'] as int, IntakeStatus.taken);
    return true;
  }

  // ================= Vue d'ensemble (écran principal) =================

  /// Un seul aller-retour SQL -> liste + adhérence.
  /// Passe aussi automatiquement les traitements "active"
  /// dont la date de fin est passée en "completed".
  Future<TreatmentOverview> overview(int userId) async {
    final db = await _db;
    await _autoComplete();

    // ---- adhérence 7 derniers jours (sur prises passées uniquement)
    final weekRows = await db.rawQuery('''
      SELECT substr(l.scheduled_at, 1, 10) AS d,
             COUNT(*) AS total,
             SUM(CASE WHEN l.status = 'taken' THEN 1 ELSE 0 END) AS taken
      FROM intake_logs l
      JOIN treatments t ON t.id = l.treatment_id
      WHERE t.user_id = ?
        AND substr(l.scheduled_at, 1, 10) >= ?
        AND l.scheduled_at <= ?
      GROUP BY d
    ''', [userId, _dayToIso(_now().subtract(const Duration(days: 6))), _nowIso]);
    final byDay = <String, (int, int)>{}; // date -> (total, taken)
    for (final r in weekRows) {
      byDay[r['d'] as String] =
          ((r['total'] ?? 0) as int, (r['taken'] ?? 0) as int);
    }
    final week = List<DayStat>.generate(7, (i) {
      final day = _dayStart(_now()).subtract(Duration(days: 6 - i));
      final rec = byDay[_dayToIso(day)];
      return DayStat(day: day, taken: rec?.$2 ?? 0, total: rec?.$1 ?? 0);
    });
    final tot = week.fold<int>(0, (a, s) => a + s.total);
    final taken = week.fold<int>(0, (a, s) => a + s.taken);
    final adherence = tot == 0 ? null : taken / tot;

    // ---- liste des traitements + agrégats par traitement
    final rows = await db.rawQuery('''
      SELECT t.*,
        (SELECT COUNT(*) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.status = 'taken'
            AND l.scheduled_at <= ?) AS taken_count,
        (SELECT COUNT(*) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.scheduled_at <= ?) AS past_count,
        (SELECT MIN(scheduled_at) FROM intake_logs l
          WHERE l.treatment_id = t.id
            AND l.status = 'pending'
            AND l.scheduled_at >= ?) AS next_dose
      FROM treatments t
      WHERE t.user_id = ?
      ORDER BY t.end_date IS NULL DESC, t.end_date DESC
    ''', [_nowIso, _nowIso, _nowIso, userId]);

    final summaries = rows.map((r) {
      final next = r['next_dose'] as String?;
      return TreatmentSummary(
        treatment: Treatment.fromMap(r),
        takenCount: (r['taken_count'] ?? 0) as int,
        pastCount: (r['past_count'] ?? 0) as int,
        nextDose: next == null ? null : DateTime.parse(next),
      );
    }).toList();

    final active = summaries
        .where((s) => s.treatment.status == TreatmentStatus.active ||
            s.treatment.status == TreatmentStatus.planned)
        .toList();
    final past = summaries
        .where((s) => s.treatment.status == TreatmentStatus.stopped ||
            s.treatment.status == TreatmentStatus.completed)
        .toList();
    return TreatmentOverview(
        adherence: adherence, week: week, active: active, past: past);
  }

  /// Doses à venir (fenêtre [hours] heures) pour programmer les
  /// notifications locales. Seuls les traitements encore actifs/planned
  /// et les prises "pending" sont pris en compte.
  Future<List<UpcomingDose>> upcomingDoses(int userId,
      {int hours = 48}) async {
    final db = await _db;
    final now = _now();
    final limit = now.add(Duration(hours: hours));
    
    // Debug info
    debugPrint('[DB] upcomingDoses request: userId=$userId, now=${now.toIso8601String()}, limit=${limit.toIso8601String()}');

    final rows = await db.rawQuery('''
      SELECT l.*, t.medication_name, t.medication_dosage, t.dose
      FROM intake_logs l
      JOIN treatments t ON t.id = l.treatment_id
      WHERE t.user_id = ?
        AND t.status IN ('active', 'planned')
        AND l.status = ?
        AND l.scheduled_at >= ?
        AND l.scheduled_at <= ?
      ORDER BY l.scheduled_at
      LIMIT 100
    ''', [
      userId,
      IntakeStatus.pending.name,
      now.toIso8601String(),
      limit.toIso8601String(),
    ]);
    
    debugPrint('[DB] upcomingDoses result: ${rows.length} rows');
    return rows
        .map((r) => UpcomingDose(
              log: IntakeLog.fromMap(r),
              medicationName: r['medication_name'] as String,
              dosage: r['medication_dosage'] as String?,
              dose: r['dose'] as String,
            ))
        .toList();
  }

  /// completed automatique quand endDate est passée (règle doc §8)
  Future<void> _autoComplete() async {
    final db = await _db;
    await db.update(
      'treatments',
      {'status': TreatmentStatus.completed.name},
      where: "status IN ('active', 'planned') AND end_date IS NOT NULL "
          'AND end_date < ?',
      whereArgs: [_dayToIso(_now())],
    );
  }

  // ================= Génération des prises planifiées =================

  Future<void> _generateLogs(Treatment t, {DateTime? from}) async {
    if (t.reminderTimes.isEmpty) return;
    final db = await _db;
    final now = _now();
    final start = from ?? _dayStart(t.startDate);
    final end = t.endDate ?? start.add(const Duration(days: 60));
    final last = _dayStart(end);
    final today = _dayStart(now);
    
    debugPrint('[DB] _generateLogs for ${t.medicationName}: start=${start.toIso8601String()}, end=${end.toIso8601String()}, now=${now.toIso8601String()}');
    
    var cursor = start.isBefore(today) ? today : start;
    if (cursor.isAfter(last)) return;
    // garde-fou : ne jamais générer plus de 180 jours
    final hardStop = last.isAfter(cursor.add(const Duration(days: 180)))
        ? cursor.add(const Duration(days: 180))
        : last;
    const batchMax = 2000;
    var count = 0;
    while (!cursor.isAfter(hardStop) && count < batchMax) {
      for (final time in t.reminderTimes) {
        final hm = _parseTime(time);
        if (hm == null) continue;
        final scheduled = DateTime(
            cursor.year, cursor.month, cursor.day, hm.$1, hm.$2);
        
        // Log de chaque créneau testé
        debugPrint('[DB] test créneau: ${scheduled.toIso8601String()}');
        
        if (scheduled.isBefore(now)) {
          debugPrint('[DB] ignoré car passé');
          continue;
        }
        final log = IntakeLog(
          treatmentId: t.id!,
          scheduledAt: scheduled,
        );
        debugPrint('[DB] génère log pour ${t.medicationName} à ${scheduled.toIso8601String()}');
        await db.insert('intake_logs', log.toMap()..remove('id'));
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  Future<void> _deleteFutureLogs(Treatment t) => _deleteFutureLogsById(t.id!);

  Future<void> _deleteFutureLogsById(int treatmentId) async {
    final db = await _db;
    await db.delete(
      'intake_logs',
      where: 'treatment_id = ? AND status = ? AND scheduled_at > ?',
      whereArgs: [treatmentId, IntakeStatus.pending.name, _nowIso],
    );
  }

  // ================= Utilitaires dates =================

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dayToIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static (int, int)? _parseTime(String time) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return (h, min);
  }
}
