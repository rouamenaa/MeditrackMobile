/// ============================================================
/// Module – MÉDICAMENTS : écran principal
/// Catalogue personnel des médicaments de l'utilisateur.
///
/// Patterns du cours utilisés :
///  - StatefulWidget : future créé dans initState (JAMAIS dans build)
///  - FutureBuilder : Loading / Error / Empty / Data
///  - ListView : liste des médicaments
///  - SearchBar : recherche en temps réel (setState -> rebuild)
/// ============================================================
library;

import 'package:flutter/material.dart';
import '../../auth/models/user.dart';
import '../models/medication.dart';
import '../repositories/medication_repository.dart';
import 'medication_form_screen.dart';
import 'medication_detail_screen.dart';

// ---------- Palette (identique à celle d'Oussama pour cohérence du merge) ----------
const kBg = Color(0xFFF4F8F7);
const kPrimary = Color(0xFF0B6B5D);
const kGreen = Color(0xFF12B76A);
const kGreenSoft = Color(0xFFDCFCE7);
const kTealSoft = Color(0xFFE0F2F1);
const kBlueSoft = Color(0xFFDBEAFE);
const kOrangeSoft = Color(0xFFFFF7ED);
const kRedSoft = Color(0xFFFFE4E6);
const kTextDark = Color(0xFF1F2937);
const kMuted = Color(0xFF6B7280);

class MedicationsScreen extends StatefulWidget {
  final User user;
  const MedicationsScreen({super.key, required this.user});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _repo = MedicationRepository();
  final _searchCtrl = TextEditingController();

  late Future<List<Medication>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Le Future est stocké dans une variable d'état (piège du cours !)
    _future = _repo.allForUser(widget.user.id!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _query.isEmpty
          ? _repo.allForUser(widget.user.id!)
          : _repo.search(widget.user.id!, _query);
    });
  }

  void _onSearch(String value) {
    setState(() {
      _query = value;
      _future = value.isEmpty
          ? _repo.allForUser(widget.user.id!)
          : _repo.search(widget.user.id!, value);
    });
  }

  Future<void> _openForm({Medication? existing}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MedicationFormScreen(
        userId: widget.user.id!,
        medication: existing,
      ),
    ));
    _reload();
  }

  Future<void> _openDetail(Medication med) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MedicationDetailScreen(
        user: widget.user,
        medication: med,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Mes médicaments',
          style: TextStyle(
              color: kTextDark, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouveau médicament',
            icon: const Icon(Icons.add_circle_rounded, color: kPrimary),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(child: _listView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        tooltip: 'Ajouter un médicament',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------- Barre de recherche ----------
  Widget _searchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Rechercher un médicament…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: kMuted),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: kMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: kBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ---------- Liste principale ----------
  Widget _listView() {
    return FutureBuilder<List<Medication>>(
      future: _future,
      builder: (context, snapshot) {
        // Pattern Loading / Error / Empty du cours
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final meds = snapshot.data!;
        if (meds.isEmpty) return _emptyState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: meds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _medicationCard(meds[i]),
        );
      },
    );
  }

  // ---------- État vide ----------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kTealSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.medication_rounded,
                color: kPrimary, size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty
                ? 'Aucun médicament enregistré'
                : 'Aucun résultat pour "$_query"',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: kTextDark),
          ),
          const SizedBox(height: 8),
          Text(
            _query.isEmpty
                ? 'Appuyez sur + pour ajouter votre premier médicament.'
                : 'Essayez un autre terme de recherche.',
            style: const TextStyle(color: kMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------- Carte d'un médicament ----------
  Widget _medicationCard(Medication med) {
    final hasLowStock = med.isLowStock;
    final hasExpired = med.isExpired;
    final isExpiringSoon = med.isExpiringSoon && !hasExpired;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetail(med),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône forme pharmaceutique
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _formColor(med.form),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_formIcon(med.form),
                      color: _formIconColor(med.form), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badges
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              med.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: kTextDark),
                            ),
                          ),
                          if (hasExpired)
                            _badge('Expiré', kRedSoft, const Color(0xFFDC2626))
                          else if (isExpiringSoon)
                            _badge('Expire bientôt', kOrangeSoft,
                                const Color(0xFFD97706))
                          else if (hasLowStock)
                            _badge('Stock bas', kOrangeSoft,
                                const Color(0xFFD97706)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Dosage · Forme
                      Text(
                        med.fullLabel,
                        style:
                            const TextStyle(color: kMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (med.manufacturer != null &&
                          med.manufacturer!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          med.manufacturer!,
                          style: const TextStyle(
                              color: kMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Stock + date d'expiration
                      Row(
                        children: [
                          if (med.stockQuantity != null) ...[
                            const Icon(Icons.inventory_2_outlined,
                                size: 14, color: kMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Stock : ${med.stockQuantity} unité(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasLowStock
                                    ? const Color(0xFFD97706)
                                    : kMuted,
                                fontWeight: hasLowStock
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (med.expiryDate != null) ...[
                            const Icon(Icons.event_outlined,
                                size: 14, color: kMuted),
                            const SizedBox(width: 4),
                            Text(
                              _fmtDate(med.expiryDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasExpired
                                    ? const Color(0xFFDC2626)
                                    : isExpiringSoon
                                        ? const Color(0xFFD97706)
                                        : kMuted,
                                fontWeight:
                                    (hasExpired || isExpiringSoon)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: kMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );

  // --------- Helpers forme pharmaceutique ---------
  Color _formColor(MedicationForm f) {
    switch (f) {
      case MedicationForm.comprime:
      case MedicationForm.gelule:
        return kTealSoft;
      case MedicationForm.sirop:
        return kBlueSoft;
      case MedicationForm.injection:
        return kRedSoft;
      case MedicationForm.pommade:
      case MedicationForm.patch:
        return kOrangeSoft;
      default:
        return kGreenSoft;
    }
  }

  Color _formIconColor(MedicationForm f) {
    switch (f) {
      case MedicationForm.comprime:
      case MedicationForm.gelule:
        return kPrimary;
      case MedicationForm.sirop:
        return const Color(0xFF2563EB);
      case MedicationForm.injection:
        return const Color(0xFFDC2626);
      case MedicationForm.pommade:
      case MedicationForm.patch:
        return const Color(0xFFD97706);
      default:
        return kGreen;
    }
  }

  IconData _formIcon(MedicationForm f) {
    switch (f) {
      case MedicationForm.comprime:
        return Icons.medication_rounded;
      case MedicationForm.gelule:
        return Icons.circle_outlined;
      case MedicationForm.sirop:
        return Icons.water_drop_outlined;
      case MedicationForm.injection:
        return Icons.vaccines_outlined;
      case MedicationForm.pommade:
        return Icons.sanitizer_outlined;
      case MedicationForm.patch:
        return Icons.healing_outlined;
      case MedicationForm.gouttes:
        return Icons.opacity_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
