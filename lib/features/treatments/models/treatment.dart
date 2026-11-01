/// ============================================================
/// Module 3.3 — TRAITEMENTS (Treatment)
/// Modèle + historique des prises (IntakeLog)
///
/// Toutes les dates/heures sont stockées en ISO 8601 (TEXT)
/// -> comparable directement dans les requêtes SQL.
/// ============================================================
library;

/// Cycle de vie du traitement (diagramme d'états, doc §8)
enum TreatmentStatus { planned, active, stopped, completed }

/// État d'une prise planifiée
enum IntakeStatus { pending, taken, missed, skipped }

// ---------- Helpers de conversion texte <-> enum ----------
TreatmentStatus treatmentStatusFromString(String s) =>
    TreatmentStatus.values.firstWhere((e) => e.name == s,
        orElse: () => TreatmentStatus.planned);

IntakeStatus intakeStatusFromString(String s) =>
    IntakeStatus.values.firstWhere((e) => e.name == s,
        orElse: () => IntakeStatus.pending);

// ---------- IntakeLog : une prise planifiée (composition : ne vit pas sans son traitement) ----------
class IntakeLog {
  final int? id;
  final int treatmentId;
  final DateTime scheduledAt; // prévu à
  final DateTime? takenAt;    // pris / ignoré à
  final IntakeStatus status;

  IntakeLog({
    this.id,
    required this.treatmentId,
    required this.scheduledAt,
    this.takenAt,
    this.status = IntakeStatus.pending,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'treatment_id': treatmentId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'taken_at': takenAt?.toIso8601String(),
        'status': status.name,
      };

  factory IntakeLog.fromMap(Map<String, dynamic> m) => IntakeLog(
        id: m['id'] as int?,
        treatmentId: m['treatment_id'] as int,
        scheduledAt: DateTime.parse(m['scheduled_at'] as String),
        takenAt: m['taken_at'] == null
            ? null
            : DateTime.parse(m['taken_at'] as String),
        status: intakeStatusFromString(m['status'] as String? ?? 'pending'),
      );
}

// ---------- Treatment : le protocole ----------
class Treatment {
  final int? id;
  final int userId; // FK -> users(id)
  final String medicationName; // nom du médicament (module 3.2 pas encore mergé)
  final String? medicationDosage; // ex : "500 mg capsule"
  final String dose; // ex : "1 comprimé"
  final List<String> reminderTimes; // ex : ["08:00", "20:00"]
  final DateTime startDate; // AAAA-MM-JJ
  final DateTime? endDate; // null = traitement chronique (continu)
  final TreatmentStatus status;

  Treatment({
    this.id,
    required this.userId,
    required this.medicationName,
    this.medicationDosage,
    required this.dose,
    required this.reminderTimes,
    required this.startDate,
    this.endDate,
    this.status = TreatmentStatus.active,
  });

  bool get isChronic => endDate == null;
  bool get isActive => status == TreatmentStatus.active || status == TreatmentStatus.planned;
  bool get hasExpiredDate =>
      endDate != null && endDate!.isBefore(_dayStart(DateTime.now()));

  /// Nombre de prises par jour = nombre d'horaires
  int get timesPerDay => reminderTimes.length;

  /// "2x par jour (Matin & Soir)"
  String get frequencyLabel {
    if (reminderTimes.isEmpty) return '—';
    final n = '${reminderTimes.length}x';
    final moments = reminderTimes
        .map(_momentOf)
        .whereType<String>()
        .toSet()
        .toList();
    final detail = moments.isEmpty ? '' : ' (${moments.join(' & ')})';
    if (moments.length == 1) {
      final m = moments.first;
      if (m == 'Matin' || m == 'Soir') return '$n par ${m.toLowerCase()}$detail';
    }
    return '$n par jour$detail';
  }

  static String? _momentOf(String time) {
    final parts = time.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts.first);
    if (h == null) return null;
    if (h < 12) return 'Matin';
    if (h < 18) return 'Après-midi';
    return 'Soir';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'medication_name': medicationName,
        'medication_dosage': medicationDosage,
        'dose': dose,
        'reminder_times': _encodeTimes(reminderTimes),
        'start_date': _dateIso(startDate),
        'end_date': endDate == null ? null : _dateIso(endDate!),
        'status': status.name,
      };

  factory Treatment.fromMap(Map<String, dynamic> m) => Treatment(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        medicationName: m['medication_name'] as String,
        medicationDosage: m['medication_dosage'] as String?,
        dose: m['dose'] as String,
        reminderTimes: _decodeTimes(m['reminder_times'] as String? ?? ''),
        startDate: DateTime.parse((m['start_date'] as String).substring(0, 10)),
        endDate: (m['end_date'] as String?) == null
            ? null
            : DateTime.parse((m['end_date'] as String).substring(0, 10)),
        status: treatmentStatusFromString(m['status'] as String? ?? 'active'),
      );

  /// Encode "08:00,20:00" -> stocké directement en TEXT simple.
  static String _encodeTimes(List<String> times) => times.join(',');
  static List<String> _decodeTimes(String raw) => raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t))
      .toList();

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "AAAA-MM-JJ" sans l'heure (colonne TEXT)
  static String _dateIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
