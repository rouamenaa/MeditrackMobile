/// ============================================================
/// Module 3.3 — TRAITEMENTS : historique des prises (IntakeLog)
///
/// Patterns du cours :
///  - FutureBuilder + formulas Loading/Error/Empty
///  - regroupement par date (`Map<String, List<IntakeLog>>`)
///  - showDialog : confirmation avant suppression
///  - update/delete sqflite TOUJOURS avec where + whereArgs
/// Règles métier :
///  - Stop : l'historique est conservé, les prises futures annulées
///  - L'historique (IntakeLog) est la composition de Treatment :
///    supprimer le traitement supprime ses prises.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../auth/models/user.dart';
import '../models/treatment.dart';
import '../repositories/treatment_repository.dart';
import '../utils/date_fr.dart';
import 'treatment_form_screen.dart';

class TreatmentHistoryScreen extends StatefulWidget {
  final User user;
  final TreatmentSummary summary;
  final VoidCallback onChanged; // recharge la liste principale
  const TreatmentHistoryScreen(
      {super.key, required this.user, required this.summary, required this.onChanged});

  @override
  State<TreatmentHistoryScreen> createState() => _TreatmentHistoryScreenState();
}

class _TreatmentHistoryScreenState extends State<TreatmentHistoryScreen> {
  final _repo = TreatmentRepository();

  /// Résumé mutable : après une modification, on va chercher une version
  /// fraîche dans la base (nom, statut, compteurs, prochaine prise).
  late TreatmentSummary _summary = widget.summary;

  late Future<List<IntakeLog>> _logs;

  @override
  void initState() {
    super.initState();
    _logs = _repo.logsOf(_summary.treatment.id!);
  }

  /// Rafraîchit le résumé ET les prises après chaque mutation
  /// (modification, arrêt, prise marquée...) + prévient l'écran liste.
  /// Piège du cours : JAMAIS de setState(() => await ...)
  Future<void> _reload() async {
    final fresh =
        await _repo.summaryFor(_summary.treatment.id!, widget.user.id!);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _summary = fresh; // null = supprimé entre-temps
      _logs = _repo.logsOf(_summary.treatment.id!);
    });
    widget.onChanged();
  }

  /// Ouvre le formulaire en modification, PUIS rafraîchit tout
  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TreatmentFormScreen(
        userId: widget.user.id!,
        treatment: _summary.treatment,
      ),
    ));
    await _reload();
  }

  // ---------- actions ----------

  Future<void> _mark(IntakeLog log, IntakeStatus status) async {
    await _repo.markLog(log.id!, status);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
      status == IntakeStatus.taken
          ? 'Prise validée ✓'
          : status == IntakeStatus.skipped
              ? 'Prise ignorée'
              : 'Statut mis à jour',
    )));
  }

  Future<void> _stopTreatment() async {
    final t = _summary.treatment;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Arrêter ce traitement ?'),
        content: Text(
            '« ${t.medicationName} » passera en statut "Arrêté".\n'
            'Les prises à venir restent consultables dans l\'historique '
            'mais ne sont plus générées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Non')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Oui, arrêter')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _repo.stop(t.id!);
      await _reload(); // statut frais + rechargement des prises
    }
  }

  Future<void> _deleteTreatment() async {
    final t = _summary.treatment;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text(
            '« ${t.medicationName} » et TOUT son historique de prises seront '
            'supprimés définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(t.id!);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final t = _summary.treatment;
    final canStop = t.status == TreatmentStatus.active ||
        t.status == TreatmentStatus.planned;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(t.medicationName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            tooltip: 'Modifier',
            onPressed: _edit, // attend la fin du form PUIS rafraîchit
          ),
          if (canStop)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, size: 22),
              tooltip: 'Arrêter',
              onPressed: _stopTreatment,
            ),
          if (!canStop)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Supprimer',
              onPressed: _deleteTreatment, // toujours avec confirmation
            ),
        ],
      ),
      body: FutureBuilder<List<IntakeLog>>(
        future: _logs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0B6B5D)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('Aucun élément'));
          }
          return _buildGroupedList(t, logs);
        },
      ),
    );
  }

  /// Regroupe les prises par journée : { «2026-11-02 » : [IntakeLog, ...] }
  Widget _buildGroupedList(Treatment t, List<IntakeLog> logs) {
    final groups = <String, List<IntakeLog>>{};
    for (final l in logs) {
      final key = l.scheduledAt.toIso8601String().substring(0, 10);
      groups.putIfAbsent(key, () => []).add(l);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(t, logs),
        const SizedBox(height: 16),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              fmtDateLettres(DateTime.parse(e.key)),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
            ),
          ),
          for (final log in e.value) _logTile(log, e.key),
          const SizedBox(height: 2),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Carte d'en-tête : statut + progression + règles du plan
  Widget _headerCard(Treatment t, List<IntakeLog> logs) {
    final now = DateTime.now();
    final pastLogs = logs.where((l) => l.scheduledAt.isBefore(now)).toList();
    final taken = pastLogs.where((l) => l.status == IntakeStatus.taken).length;
    final pct = pastLogs.isEmpty ? 0.0 : taken / pastLogs.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication_rounded, color: Color(0xFF0B6B5D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${t.medicationDosage ?? t.dose} · ${t.dose}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusChip(t.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(t.frequencyLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            t.isChronic
                ? 'Traitement chronique (sans date de fin)'
                : '${fmtDate(t.startDate)} – ${fmtDate(t.endDate!)}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Progression',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              const Spacer(),
              Text(
                'Prises prises : $taken sur ${pastLogs.length}',
                style: const TextStyle(
                    color: Color(0xFF0B6B5D),
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE0F2F1),
              color: const Color(0xFF12B76A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(TreatmentStatus s) {
    final (label, bg, fg) = switch (s) {
      TreatmentStatus.active => ('Active', const Color(0xFFDCFCE7), const Color(0xFF12B76A)),
      TreatmentStatus.planned => ('Planifié', const Color(0xFFEDE9FE), const Color(0xFF7C3AED)),
      TreatmentStatus.stopped => ('Arrêté', const Color(0xFFFCE7F3), const Color(0xFFDB2777)),
      TreatmentStatus.completed => ('Terminé', const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  /// Une ligne = une prise planifiée
  Widget _logTile(IntakeLog log, String dayKey) {
    final now = DateTime.now();
    final isToday = log.scheduledAt.toIso8601String().substring(0, 10) == now.toIso8601String().substring(0, 10);
    final canEdit = isToday && log.status == IntakeStatus.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: boxShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _logColor(log.status).bg,
                shape: BoxShape.circle,
              ),
              child: Icon(_logColor(log.status).icon, size: 18, color: _logColor(log.status).fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmtTime(log.scheduledAt),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    log.status == IntakeStatus.taken
                        ? 'Pris${log.takenAt != null ? ' à ${fmtTime(log.takenAt!)}' : ''}'
                        : log.status == IntakeStatus.skipped
                            ? 'Ignorée'
                            : log.status == IntakeStatus.missed
                                ? 'Manquée'
                                : 'À prendre',
                    style: TextStyle(
                        color: _logColor(log.status).fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (canEdit) ...[
              IconButton(
                tooltip: 'Pris',
                icon: const Icon(Icons.check_rounded, color: Color(0xFF12B76A)), onPressed: () => _mark(log, IntakeStatus.taken),
              ),
              IconButton(
                tooltip: 'Ignorée',
                icon: const Icon(Icons.close_rounded, color: Color(0xFFDB2777)),
                onPressed: () => _mark(log, IntakeStatus.skipped),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_field
  static const List<BoxShadow> boxShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  ({Color bg, Color fg, IconData icon}) _logColor(IntakeStatus s) {
    switch (s) {
      case IntakeStatus.taken:
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF12B76A), icon: Icons.check_rounded);
      case IntakeStatus.skipped:
        return (bg: const Color(0xFFFCE7F3), fg: const Color(0xFFDB2777), icon: Icons.close_rounded);
      case IntakeStatus.missed:
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFDC2626), icon: Icons.schedule);
      case IntakeStatus.pending:
        return (bg: const Color(0xFFE0F2F1), fg: const Color(0xFF0B6B5D), icon: Icons.alarm_rounded);
    }
  }
}
