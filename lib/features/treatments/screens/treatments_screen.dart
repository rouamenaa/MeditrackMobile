/// ============================================================
/// Module 3.3 — TRAITEMENTS : écran principal
/// Design "Active Treatments & Plans" (maquette fournie).
///
/// Patterns du cours utilisés :
///  - StatefulWidget : future créé dans initState (JAMAIS dans build)
///  - FutureBuilder : Loading / Error / Empty
///  - ListView : petites listes fixes (nombre d'enfants raisonnable)
///  - BottomNavigationBar : navigation basse + setState pour l'onglet
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../auth/models/user.dart';
import '../models/treatment.dart';
import '../repositories/treatment_repository.dart';
import '../services/medication_reminder_service.dart';
import '../utils/date_fr.dart';
import 'treatment_form_screen.dart';
import 'treatment_history_screen.dart';

// ---------- Palette de la maquette ----------
const kBgDark = Color(0xFF14181B); // barre du haut / barre du bas
const kPrimary = Color(0xFF0B6B5D); // vert MediTrack (thème app)
const kGreen = Color(0xFF12B76A); // carte adhérence
const kGreenSoft = Color(0xFFDCFCE7);
const kTealSoft = Color(0xFFE0F2F1);
const kBlueSoft = Color(0xFFDBEAFE);
const kPinkSoft = Color(0xFFFCE7F3);
const kBg = Color(0xFFF4F8F7); // fond des écrans
const kTextDark = Color(0xFF1F2937);
const kMuted = Color(0xFF6B7280);

class TreatmentsScreen extends StatefulWidget {
  final User user;
  const TreatmentsScreen({super.key, required this.user});

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> {
  final _repo = TreatmentRepository();
  final _reminders = MedicationReminderService();

  // Onglet initial = "Traitements" (3e bouton de la barre du bas)
  // int _tab = 2; // [MERGE] décommenté avec la barre du bas (voir plus bas)

  late Future<TreatmentOverview> _future;

  @override
  void initState() {
    super.initState();
    // Le Future est stocké dans une variable d'état (piège du cours !)
    _future = _repo.overview(widget.user.id!);
    // Rappels de dose : programmation des 48 prochaines heures
    // (fire-and-forget, ne bloque pas l'affichage)
    _reminders.refresh(widget.user.id!);
  }

  void _reload() {
    setState(() {
      // NE PAS retourner le Future depuis setState (piège du cours) :
      // on lance l'appel puis on garde la MAJ d'état synchrone.
      _future = _repo.overview(widget.user.id!);
    });
    // Après chaque mutation (création/prise/arrêt...) : resynchronisation
    // des rappels. Le service part de cancelAll() donc c'est idempotent.
    _reminders.refresh(widget.user.id!);
  }

  // ---------- Navigations ----------

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  Future<void> _openForm({Treatment? existing}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TreatmentFormScreen(
        userId: widget.user.id!,
        treatment: existing,
      ),
    ));
    _reload();
  }

  Future<void> _openDetails(TreatmentSummary s) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TreatmentHistoryScreen(
        user: widget.user,
        summary: s,
        onChanged: _reload,
      ),
    ));
    _reload();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // [MODIF 3.3] Barre du haut supprimée (bouton cloche sans action) +
      // barre du bas commentée en attendant le merge des modules.
      // body: SafeArea(
      //   child: Column(
      //     children: [
      //       _topBar(),
      //       Expanded(child: _body()),
      //     ],
      //   ),
      // ),
      // bottomNavigationBar: _bottomBar(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('Mes traitements',
            style: TextStyle(
                color: kTextDark, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Nouveau traitement',
            icon: const Icon(Icons.add_circle_rounded, color: kPrimary),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      // [NAVIGATION MERGE] Le lien de retour vers l'Accueil est la flèche
      // de l'AppBar (l'écran est push depuis home_screen).
      body: _treatmentsView(),
    );
  }

  /// Barre du haut sombre façon maquette (logo + MediTrack + cloche)
  /// [MERGE] Supprimée à la demande : le bouton cloche n'était pas
  /// fonctionnel. Code conservé pour la rebrancher plus tard.
  // Widget _topBar() {
  //   final u = widget.user;
  //   return Container(
  //     color: kBgDark,
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //     child: Row(
  //       children: [
  //         const Icon(Icons.menu, color: Colors.white70),
  //         const SizedBox(width: 10),
  //         Container(
  //           width: 34,
  //           height: 34,
  //           decoration: const BoxDecoration(
  //             shape: BoxShape.circle,
  //             gradient: LinearGradient(
  //               colors: [kPrimary, kGreen],
  //               begin: Alignment.topLeft,
  //               end: Alignment.bottomRight,
  //             ),
  //           ),
  //           alignment: Alignment.center,
  //           child: const Text('M',
  //               style: TextStyle(
  //                   color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
  //         ),
  //         const SizedBox(width: 10),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('MediTrack',
  //                   style: const TextStyle(
  //                       color: Colors.white,
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 15)),
  //               Text('${u.prenom} ${u.nom}',
  //                   style: const TextStyle(color: Colors.white54, fontSize: 11)),
  //             ],
  //           ),
  //         ),
  //         Container(
  //           width: 36,
  //           height: 36,
  //           decoration: BoxDecoration(
  //             color: Colors.white12,
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //           child: const Icon(Icons.notifications_none, color: Colors.greenAccent),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// Contenu de l'onglet actif (seul l'onglet "Traitements" est le mien)
  /// [MERGE] Inutile tant que la barre du bas est commentée.
  // Widget _body() {
  //   if (_tab == 2) return _treatmentsView();
  //   return _PagePlaceholder(index: _tab);
  // }

  // ---------- Écran "Traitements" ----------

  Widget _treatmentsView() {
    return FutureBuilder<TreatmentOverview>(
      future: _future,
      builder: (context, snapshot) {
        // Pattern Loading / Error / Empty du cours
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final ov = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _titleRow(ov),
            const SizedBox(height: 16),
            _adherenceCard(ov),
            const SizedBox(height: 20),
            ..._activeCards(ov),
            if (ov.past.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionTitle('PROTOCOLES TERMINÉS', '${ov.past.length} Archivé(s)'),
              const SizedBox(height: 10),
              ..._pastCards(ov.past),
            ],
          ],
        );
      },
    );
  }

  /// Titre "Traitements actifs & plans" + bouton +
  Widget _titleRow(TreatmentOverview ov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Traitements actifs\n& plans',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: kTextDark, height: 1.15),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openForm(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: .35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
            ),
            const SizedBox(width: 6),
            Text('${ov.active.length} protocole(s) de traitement actif(s)',
                style: const TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // ---------- Carte d'adhérence (diagramme en mini-barres) ----------

  Widget _adherenceCard(TreatmentOverview ov) {
    final pct = ov.adherence;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kGreen.withValues(alpha: .35),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adhérence hebdo',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  pct == null ? '— %' : '${(pct * 100).round()} %',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                Text(
                  pct == null
                      ? 'Aucune prise planifiée cette semaine'
                      : pct >= 0.8
                          ? 'Sur la bonne voie'
                          : 'Prises manquées cette semaine',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Mini graphique : 1 barre par jour (7 jours)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in ov.week)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 9,
                  height: 22 + (d.total == 0 ? 0 : 26 * d.taken / d.total).round().toDouble(),
                  decoration: BoxDecoration(
                    color: d.total == 0
                        ? Colors.white24
                        : d.taken == d.total
                            ? Colors.white
                            : Colors.white54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String left, String right) {
    return Row(
      children: [
        Text(left,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: .5)),
        const Spacer(),
        Text(right, style: const TextStyle(fontSize: 12, color: kMuted)),
      ],
    );
  }

  // ---------- Cartes des traitements actifs ----------

  List<Widget> _activeCards(TreatmentOverview ov) {
    if (ov.active.isEmpty) {
      return [
        const SizedBox(height: 0),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration(),
          child: Column(
            children: const [
              Icon(Icons.medication_rounded, color: kMuted, size: 40),
              SizedBox(height: 10),
              Text('Aucun traitement actif',
                  style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
              SizedBox(height: 4),
              Text('Appuyez sur + pour créer votre premier protocole.',
                  style: TextStyle(color: kMuted, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ];
    }
    return [
      for (final s in ov.active)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _activeCard(s),
        ),
    ];
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _activeCard(TreatmentSummary s) {
    final t = s.treatment;
    final now = DateTime.now();
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetails(s), // consulter l'historique
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ligne 1 : icône + nom + badge
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: kTealSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_rounded, color: kPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.medicationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kTextDark)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.medicationDosage ?? '—'} · ${t.dose}',
                                  style: const TextStyle(color: kMuted, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _badge('Active', kGreenSoft, kGreen),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // --- ligne 2 : fréquence + prochaine prise
                Row(
                  children: [
                    const Icon(Icons.update_rounded, size: 16, color: kMuted),
                    const SizedBox(width: 6),
                    Text(t.frequencyLabel, style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: kPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.hasExpiredDate
                            ? 'Période terminée'
                            : 'Prochaine dose : ${fmtProchainePrise(s.nextDose, now)}',
                        style: const TextStyle(
                            color: kPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (!t.isChronic) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        'Se termine le ${fmtDate(t.endDate!)}',
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // --- ligne 3 : progression
                Row(
                  children: [
                    const Text('Progression du traitement',
                        style: TextStyle(color: kMuted, fontSize: 11)),
                    const Spacer(),
                    Text('${(s.progress * 100).round()} %',
                        style: const TextStyle(
                            color: kPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: s.progress,
                    minHeight: 8,
                    backgroundColor: kTealSoft,
                    color: kGreen,
                  ),
                ),
                const SizedBox(height: 12),
                // --- ligne 4 : dates + bouton Valider la prise
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16, color: kMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fmtPeriode(t.startDate, t.endDate),
                        style: const TextStyle(color: kMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await _repo.logNextDose(t.id!);
                        _snack(ok
                            ? 'Prise enregistrée ✅ (${fmtTime(now)})'
                            : 'Aucune prise en attente pour aujourd\'hui');
                        _reload();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: kTealSoft,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.task_alt, size: 16),
                      label: const Text('Valider dose',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Protocoles terminés / arrêtés ----------

  List<Widget> _pastCards(List<TreatmentSummary> list) {
    return [
      for (final s in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: _cardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openDetails(s),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: kBlueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.treatment.medicationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kTextDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.treatment.dose} · ${fmtPeriode(s.treatment.startDate, s.treatment.endDate)}',
                              style: const TextStyle(color: kMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(
                        s.treatment.status == TreatmentStatus.completed
                            ? 'Terminé'
                            : 'Arrêté',
                        s.treatment.status == TreatmentStatus.completed
                            ? kBlueSoft
                            : kPinkSoft,
                        s.treatment.status == TreatmentStatus.completed
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFDB2777),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ---------- Barre du bas (5 onglets, comme la maquette) ----------
  // [MERGE] Barre commentée pour l'instant : chaque onglet devient
  // l'écran du module correspondant au merge de l'équipe. Il faudra
  // alors décommenter `_tab`, `bottomNavigationBar`, `_body()`
  // et le Scaffold en Column ci-dessus.

  // Widget _bottomBar() {
  //   final items = const [
  //     (Icons.home_rounded, 'Accueil', Color(0xFF22C55E)),
  //     (Icons.medication_rounded, 'Médicaments', Color(0xFF3B82F6)),
  //     (Icons.local_pharmacy_rounded, 'Traitements', Color(0xFF14B8A6)),
  //     (Icons.calendar_month_rounded, 'Rendez-vous', Color(0xFFEC4899)),
  //     (Icons.receipt_long_rounded, 'Ordonnances', Color(0xFF9CA3AF)),
  //   ];
  //   return BottomNavigationBar(
  //     currentIndex: _tab,
  //     type: BottomNavigationBarType.fixed,
  //     onTap: (n) => setState(() => _tab = n), // setState obligatoire !
  //     backgroundColor: kBgDark,
  //     unselectedItemColor: const Color(0xFF6B7280),
  //     selectedItemColor: items[_tab].$3,
  //     selectedFontSize: 11,
  //     unselectedFontSize: 11,
  //     items: [
  //       for (var i = 0; i < items.length; i++)
  //         BottomNavigationBarItem(
  //           icon: Icon(items[i].$1, color: i == _tab ? items[i].$3 : const Color(0xFF5F6B76)),
  //           label: items[i].$2,
  //           backgroundColor: kBgDark,
  //         ),
  //     ],
  //   );
  // }
}

/// Pages des AUTRES modules (Accueil/Médicaments/Rendez-vous/Ordonnances).
/// Chaque membre du groupe remplacera le contenu de son onglet au merge.
/// [MERGE] Commenté avec la barre du bas, sera réactivé ensemble.
// class _PagePlaceholder extends StatelessWidget {
//   final int index;
//   const _PagePlaceholder({required this.index});
//
//   @override
//   Widget build(BuildContext context) {
//     final names = const ['Accueil', 'Médicaments', 'Traitements', 'Rendez-vous', 'Ordonnances'];
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Icon(Icons.construction_rounded, color: kMuted, size: 44),
//           const SizedBox(height: 10),
//           Text('Module « ${names[index]} »',
//               style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
//           const SizedBox(height: 4),
//           const Text('Écran d\'un autre membre de l\'équipe',
//               style: TextStyle(color: kMuted, fontSize: 13)),
//         ],
//       ),
//     );
//   }
// }
